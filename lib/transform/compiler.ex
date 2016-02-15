defmodule Transform.Compiler do
  require Logger
  use GenServer
  alias Transform.Interpreter
  alias Transform.Job
  alias Transform.Repo

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, %{transforms: %{}}}
  end

  defp recompile(state, job) do
    quoted = job.source
    |> Poison.decode!
    |> Interpreter.wrap

    {func, _} = Code.eval_quoted(quoted, [], __ENV__)
    state = put_in(state, [:transforms, job.id], func)
    Logger.info("Recompiled transform for #{job.id}\n\n #{Macro.to_string(quoted)}\n\n")
    {func, state}
  end

  def handle_call({:compile, dataset_id, pipeline}, _from, state) do
    source = Poison.encode!(pipeline)
    {:ok, job} = Repo.insert(%Job{
      source: source,
      dataset: dataset_id
    })
    {_, state} = recompile(state, job)
    {:reply, :ok, state}
  end

  def handle_call({:get, job}, _from, state) do
    case get_in(state, [:transforms, job.id]) do
      nil ->
        {func, state} = recompile(state, job)
        {:reply, {:ok, func}, state}
      compiled -> {:reply, {:ok, compiled}, state}
    end
  end

  def compile(dataset_id, pipeline) do
    GenServer.call(__MODULE__, {:compile, dataset_id, pipeline})
  end

  def get(job) do
    GenServer.call(__MODULE__, {:get, job})
  end
end