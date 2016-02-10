defmodule Transform.Compiler do
  require Logger
  use GenServer
  alias Transform.Interpreter

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, %{transforms: %{}}}
  end

  def handle_call({:compile, dataset_id, pipeline}, _from, state) do
    quoted = Interpreter.wrap(pipeline)
    {func, _} = Code.eval_quoted(quoted, [], __ENV__)
    state = put_in(state, [:transforms, dataset_id], func)
    Logger.info("Picked up a new transform for #{dataset_id}\n\n #{Macro.to_string(quoted)}\n\n")
    {:reply, :ok, state}
  end

  def handle_call({:get, dataset_id}, _from, state) do
    case get_in(state, [:transforms, dataset_id]) do
      nil -> {:reply, {:error, :not_found}, state}
      transform -> {:reply, {:ok, transform}, state}
    end
  end

  def compile(dataset_id, pipeline) do
    GenServer.call(__MODULE__, {:compile, dataset_id, pipeline})
  end

  def get(dataset_id) do
    GenServer.call(__MODULE__, {:get, dataset_id})
  end
end