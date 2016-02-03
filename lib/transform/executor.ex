defmodule Transform.Executor do
  use GenServer
  require Logger
  alias Transform.BasicTableServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(args) do
    {:ok, %{
      transforms: %{},
      listeners: %{}
    }}
  end

  def handle_call({:listen, dataset_id, pid}, _from, state) do
    listeners = [pid | Dict.get(state.listeners, dataset_id, [])]
    state = put_in(state, [:listeners, dataset_id], listeners)
    {:reply, :ok, state}
  end

  def handle_call({:transform, dataset_id, pipeline}, _from, state) do
    state = put_in(state, [:transforms, dataset_id], pipeline)

    Logger.info("Picked up a new transform for #{dataset_id} #{inspect pipeline}")
    BasicTableServer.listen(dataset_id, self)

    {:reply, :ok, state}
  end

  def dispatch(state, dataset_id, payload) do
    state.listeners
    |> Dict.get(dataset_id, [])
    |> Enum.each(fn listener -> send listener, payload end)
  end

  def handle_info({:header, dataset_id, header}, state) do
    dispatch(state, dataset_id, {:header, header})
    {:noreply, state}
  end

  def handle_info({:chunk, dataset_id, chunk}, state) do
    Logger.info("Executor to handle chunk for #{dataset_id}")
    
    transformed = Enum.map(chunk, fn row -> 
      state.transforms[dataset_id]
      |> Enum.reduce(row, fn func, intermediary ->
        func.(intermediary)
      end)
    end)

    dispatch(state, dataset_id, {:transformed, transformed})

    {:noreply, state}
  end

  def transform(dataset_id, pipeline) do
    GenServer.call(__MODULE__, {:transform, dataset_id, pipeline})
  end

  def listen(dataset_id) do
    GenServer.call(__MODULE__, {:listen, dataset_id, self})
  end
end