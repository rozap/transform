defmodule Transform.Executor.Worker do
  use Workex
  require Logger
  alias Transform.BasicTableServer
  alias Transform.Interpreter
  alias Transform.Compiler
  alias Transform.Repo
  alias Transform.Chunk
  alias Transform.BlobStore
  alias Transform.Backoff


  def start_link(args) do
    hwm = Application.get_env(:transform, :workers)[:executor][:high_water_mark]
    {:ok, pid} = Workex.start_link(__MODULE__, args, max_size: hwm)
    :pg2.join(__MODULE__, pid)
    {:ok, pid}
  end

  def init([id: id]) do
    Logger.info("Started #{inspect __MODULE__} #{id}")
    {:ok, %{
      transforms: %{},
      id: id
    }}
  end


  defp dispatch(dataset_id, payload) do
    case :pg2.get_members(dataset_id) do
      {:error, {:no_such_group, _}} -> {:error, :nobody_cares}
      listeners -> Enum.each(listeners, fn listener ->
        send listener, payload
      end)
    end
  end

  defp read_from_store(chunkref) do
    chunkref.location
    |> BlobStore.read!
    # |> CSV.decode
    # |> Enum.into([])
  end

  defp transform_row(_, _, [""], _, _), do: :ignore
  defp transform_row(_, columns, row, chunk, index) when length(row) != length(columns) do
    # This won't work if we vary the chunk size, but we don't...yet. Also plus one because
    # of the header
    row_num = (chunk.sequence_number * Transform.Api.BasicTable.chunk_size) + index + 1
    Logger.warn("Error on #{inspect row}")
    {:error, "Invalid row size #{length row} does not match expected size #{length columns} on row #{row_num}"}
  end
  defp transform_row(func, columns, row, _, _) do
    datum = Enum.zip(columns, row) |> Enum.into(%{})

    case func.({:ok, datum}) do
      {:ok, transformed_datum} -> {:ok, transformed_datum}
      {:error, _} = e -> e
    end
  end

  def aggregate(transformed) do
    Enum.reduce(transformed, %{}, fn row, counters ->
      Enum.reduce(row, counters, fn {colname, value}, counters ->
        counter = Map.get(counters, colname, Spacesaving.init(64))
        Map.put(counters, colname, Spacesaving.push(counter, value))
      end)
    end)
  end


  def handle_chunk({:chunk, job, basic_table, chunk}, state) do
    rows = read_from_store(chunk)

    result = case Compiler.get(job) do
      {:ok, func} ->
        rows
        |> Enum.with_index
        |> Enum.map(fn {row, index} -> transform_row(func, basic_table.meta.columns, row, chunk, index) end)
        |> Enum.group_by(fn
          {:ok, _} -> :transformed
          {:error, _} -> :errors
          :ignore -> :ignore
        end)

      {:error, _} -> %{errors: [{:error, "no transform found for #{inspect job}"}]}
    end

    # case Enum.random(1..10) do
    #   7 -> raise ArgumentError, message: "The chaos monkey is here"
    #   _ -> :ok
    # end

    successes = Dict.get(result, :transformed, [])
    errors = Dict.get(result, :errors, [])

    transformed = Enum.map(successes, fn {ok, row} -> row end)
    errors      = Enum.map(errors, fn {:error, err} -> err end)
    agg         = aggregate(transformed)

    # This isn't actually correct
    case Repo.get(Chunk, chunk.id) do
      %Chunk{completed_location: nil} ->
        dispatch(job.dataset, {:transformed, basic_table, %{
          errors: errors,
          transformed: transformed,
          aggregate: agg,
          chunk: chunk
        }})


        rows = case transformed do
          [first | _] ->
            [
              Enum.map(first, fn {k, _} -> k end) |
              Enum.map(transformed, fn row ->
                Enum.map(row, fn {_, v} -> v end)
              end)
            ]
          _ -> []
        end

        location = BlobStore.write_transformed_chunk!(job.dataset, rows)

        #let it crash here
        {:ok, chunk} = chunk
        |> Chunk.changeset(%{
          completed_at: Ecto.DateTime.utc,
          completed_location: location
        })
        |> Repo.update

        Transform.Metrics.chunk_finished(chunk)
        # Logger.info("Finished working on #{chunk.completed_at} #{chunk.inserted_at}")
      _ ->
        Logger.warn("Chunk #{chunk.id} has already been completed")

    end

    :ok
  end

  def handle(chunks, state) do
    Enum.reduce_while(chunks, :ok, fn chunk, acc ->
      case handle_chunk(chunk, state) do
        :ok -> {:cont, acc}
        {:error, reason} ->
          Logger.error("Failed to push chunk #{reason}")
          {:halt, reason}
      end
    end)

    {:ok, state}
  end


  def push(job, basic_table, chunk) do
    Backoff.try_until(
      __MODULE__,
      {:chunk, job, basic_table, chunk},
      10_000
    )
  end

end