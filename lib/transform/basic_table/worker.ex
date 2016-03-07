defmodule Transform.BasicTable.Worker do
  use Workex
  require Logger
  alias Transform.Executor.Worker
  alias Transform.Api.BasicTable
  alias Transform.Chunk
  alias Transform.Repo
  alias Transform.BlobStore
  alias Transform.Backoff

  def start_link(args) do
    # called in supervising process
    hwm = Application.get_env(:transform, :workers)[:basic_table][:high_water_mark]
    {:ok, pid} = Workex.start_link(__MODULE__, args, max_size: hwm)
    :pg2.join(__MODULE__, pid)
    {:ok, pid}
  end

  def init([id: id]) do
    # called in the context of the actual genserver once it's started
    Logger.info("Started #{inspect __MODULE__} #{id}")
    {:ok, %{
      uploads: %{},
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

  defp handle_chunk({:push, job, basic_table, sequence_number, chunk}) do
    location = BlobStore.write_basic_table_chunk!(job.dataset, chunk)

    case Repo.insert(%Chunk{
      basic_table_id: basic_table.id,
      sequence_number: sequence_number,
      location: location
    }) do
      {:ok, chunk_entry} ->
        Worker.push(job, basic_table, chunk_entry)
        dispatch(job.dataset, {:basic_table_chunk_written, %{
          chunk: chunk_entry,
          errors: []
        }})
        :ok
      err -> err
    end
  end

  def handle(chunks, state) do
    Enum.reduce_while(chunks, :ok, fn chunk, acc ->
      case handle_chunk(chunk) do
        :ok -> {:cont, acc}
        {:error, reason} ->
          Logger.error("Failed to push chunk #{reason}")
          {:halt, reason}
      end
    end)

    {:ok, state}
  end


  def push(job, basic_table, chunk_num, chunk) do
    Backoff.try_until(
      __MODULE__,
      {:push, job, basic_table, chunk_num, chunk},
      10_000
    )
  end
end