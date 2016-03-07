defmodule Transform.Compiler do
  require Logger
  use GenServer
  alias Transform.Interpreter
  alias Transform.Job
  alias Transform.Repo
  alias Transform.BasicTable
  alias Transform.Chunk
  import Ecto.Query

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

  defp get_last_job(dataset_id) do
    jobs = dataset_id
    |> Job.latest_for
    |> Repo.all

    case jobs do
      [] -> {:ok, nil}
      [j | _] -> {:ok, j}
      err -> err
    end
  end

  defp create_job(dataset_id, source) do
    Repo.insert(%Job{
      source: source,
      dataset: dataset_id
    })
  end

  defp clone_chunks(new_job, nil) do
    {:ok, {new_job, nil, []}}
  end
  defp clone_chunks(new_job, last_job) do
    basic_tables = last_job
    |> BasicTable.latest_for
    |> Repo.all

    Repo.transaction fn ->
      case basic_tables do
        [] -> {:ok, {new_job, nil, []}}
        [bt | _] ->
          {:ok, basic_table_clone} = Repo.insert(%BasicTable{
            meta: bt.meta,
            job_id: new_job.id
          })

          old_bt_id = bt.id
          clones = (from c in Chunk,
            where: c.basic_table_id == ^old_bt_id,
            select: c
          )
          |> Repo.all
          |> Enum.map(fn chunk ->
            {:ok, chunk_clone} = Repo.insert(%Chunk{
              basic_table_id: basic_table_clone.id,
              location: chunk.location,
              sequence_number: chunk.sequence_number,
            })
            chunk_clone
          end)

          {new_job, basic_table_clone, clones}
      end
    end
  end

  def handle_call({:compile, dataset_id, pipeline}, _from, state) do
    source = Poison.encode!(pipeline)

    clone_result = with {:ok, last_job} <- get_last_job(dataset_id),
      {:ok, new_job} <- create_job(dataset_id, source),
      {:ok, reply} <- clone_chunks(new_job, last_job) do
      {_, state} = recompile(state, new_job)
      {:ok, reply, state}
    end

    case clone_result do
      {:error, reason} -> {:reply, {:error, reason}, state}
      {:ok, reply, state} -> {:reply, {:ok, reply}, state}
    end
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