defmodule Transform.Executor.Worker do
  use GenServer
  require Logger
  alias Transform.BasicTableServer
  alias Transform.Interpreter
  alias Transform.Compiler
  alias Transform.Repo
  alias Transform.Chunk

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init([id: id]) do
    :pg2.join(__MODULE__, self)
    Logger.info("Started #{inspect __MODULE__} #{id}")
    {:ok, %{
      transforms: %{},
      id: id
    }}
  end


  defp dispatch(dataset_id, payload) do
    :pg2.get_members(dataset_id)
    |> Enum.each(fn listener -> send listener, payload end)
  end

  defp read_from_store(chunkref) do
    File.stream!(chunkref.location)
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


  def handle_cast({:chunk, dataset_id, basic_table, chunk}, state) do
    rows = read_from_store(chunk)

    result = case Compiler.get(dataset_id) do
      {:ok, func} ->
        rows
        |> Enum.map(fn row -> transform_row(func, basic_table.meta.columns, row) end)
        |> Enum.group_by(fn
          {:ok, _} -> :transformed
          {:error, _} -> :errors
        end)

      {:error, _} -> %{errors: [{:error, "no transform found for #{dataset_id}"}]}
    end

    # case Enum.random(1..10) do
    #   7 -> raise ArgumentError, message: "The chaos monkey is here"
    #   _ -> :ok
    # end

    successes = Dict.get(result, :transformed, [])
    errors = Dict.get(result, :errors, [])

    transformed = Enum.map(successes, fn {ok, row} -> row end)
    errors      = Enum.map(errors, fn {:error, err} -> err end)

    dispatch(dataset_id, {:transformed, basic_table, %{
      errors: errors,
      transformed: transformed,
      aggregate: aggregate(transformed),
      chunk: chunk
    }})

    cset = Chunk.changeset(chunk, %{
      completed_at: Ecto.DateTime.utc
    })
    Repo.update(cset)

    {:noreply, state}
  end

  def push(dataset_id, basic_table, chunk) do
    case Enum.take_random(:pg2.get_members(__MODULE__), 1) do
      [] -> raise ArgumentError, message: "No members of pg2 group #{inspect __MODULE__}"
      [someone] -> GenServer.cast(someone, {:chunk, dataset_id, basic_table, chunk})
    end
  end

end