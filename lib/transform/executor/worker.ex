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
    |> CSV.decode
    |> Enum.into([])
  end

  defp transform_row(_, columns, row) when length(row) != length(columns) do
    {:error, "Invalid row size #{length row} does not match expected size #{length columns}"}
  end
  defp transform_row(func, columns, row) do
    datum = Enum.zip(columns, row) |> Enum.into(%{})

    case func.({:ok, datum}) do
      {:ok, transformed_datum} -> {:ok, transformed_datum}
      {:error, _} = e -> e
    end
  end

  def aggregate(transformed) do
    Enum.reduce(transformed, %{}, fn row, acc ->
      Enum.reduce(row, acc, fn {colname, value}, acc ->
        path = [colname, value]
        acc = case acc[colname] do
          nil -> put_in(acc, [colname], %{})
          _ -> acc
        end
        acc = case acc[colname][value] do
          nil -> put_in(acc, path, 0)
          _ -> acc
        end

        current = get_in(acc, path)
        put_in(acc, path, current + 1)
      end)
    end)
  end


  def handle_chunk({:chunk, job, basic_table, chunk}, state) do
    rows = read_from_store(chunk)

    result = case Compiler.get(job) do
      {:ok, func} ->
        rows
        |> Enum.map(fn row -> transform_row(func, basic_table.meta.columns, row) end)
        |> Enum.group_by(fn
          {:ok, _} -> :transformed
          {:error, _} -> :errors
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

    # This isn't actually correct
    case Repo.get(Chunk, chunk.id) do
      %Chunk{completed_location: nil} ->
        dispatch(job.dataset, {:transformed, basic_table, %{
          errors: errors,
          transformed: transformed,
          aggregate: aggregate(transformed),
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

        cset = Chunk.changeset(chunk, %{
          completed_at: Ecto.DateTime.utc,
          completed_location: location
        })
        Repo.update(cset)
        Logger.info("Finished working on #{chunk.sequence_number} for #{job.id}")
      _ -> 
        Logger.info("Chunk #{chunk.id} has already been completed")

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