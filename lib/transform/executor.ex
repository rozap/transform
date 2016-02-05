defmodule Transform.Executor do
  use GenServer
  require Logger
  alias Transform.BasicTableServer
  alias Transform.Interpreter

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(args) do
    {:ok, %{
      transforms: %{},
      headers: %{},
      listeners: %{}
    }}
  end


  def dispatch(state, dataset_id, payload) do
    state.listeners
    |> Dict.get(dataset_id, [])
    |> Enum.each(fn listener -> send listener, payload end)
  end

  def handle_call({:listen, dataset_id, pid}, _from, state) do
    listeners = Enum.uniq([pid | Dict.get(state.listeners, dataset_id, [])])
    state = put_in(state, [:listeners, dataset_id], listeners)
    {:reply, :ok, state}
  end

  def handle_call({:transform, dataset_id, pipeline}, _from, state) do
    quoted = Interpreter.wrap(pipeline)
    IO.puts "Code gen\n\n #{Macro.to_string(quoted)}\n\n"
    {func, _} = Code.eval_quoted(quoted, [], __ENV__)

    state = put_in(state, [:transforms, dataset_id], func)

    Logger.info("Picked up a new transform for #{dataset_id}")
    BasicTableServer.listen(dataset_id)

    {:reply, :ok, state}
  end


  def handle_info({:header, dataset_id, header}, state) do
    Logger.info("Executor got a header #{inspect header}")
    state = put_in(state, [:headers, dataset_id], header)
    dispatch(state, dataset_id, {:header, header})
    {:noreply, state}
  end

  def handle_info({:chunk, dataset_id, chunk}, state) do
    header = get_in(state, [:headers, dataset_id])

    result = Enum.map(chunk, fn row ->

      func = state.transforms[dataset_id]

      datum = Enum.zip(header.columns, row) |> Enum.into(%{})

      case func.({:ok, datum}) do
        {:ok, transformed_datum} ->
          {:ok, transformed_datum}
        {:error, _} = e -> e
      end

    end)
    |> Enum.group_by(fn
      {:ok, _} -> :transformed
      {:error, _} -> :errors
    end)

    successes = Dict.get(result, :transformed, [])
    errors = Dict.get(result, :errors, [])

    transformed = Enum.map(successes, fn {ok, row} -> row end)
    errors      = Enum.map(errors, fn {:error, err} -> err end)

    dispatch(state, dataset_id, {:transformed, %{
      errors: errors,
      transformed: transformed
    }})

    {:noreply, state}
  end

  def transform(dataset_id, pipeline) do
    GenServer.call(__MODULE__, {:transform, dataset_id, pipeline})
  end

  def listen(dataset_id) do
    GenServer.call(__MODULE__, {:listen, dataset_id, self})
  end
end