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

  defp handle_chunk({:push, job, basic_table, sequence_number, chunk}) do
    try do
      Logger.info "trying to write chunk #{sequence_number} for basic_table #{basic_table.id}"
      location = BlobStore.write_basic_table_chunk!(job.dataset, chunk)
      case Repo.insert(%Chunk{
        basic_table_id: basic_table.id,
        sequence_number: sequence_number,
        location: location
      }) do
        {:ok, entry} ->
          Worker.push(job, basic_table, entry)
          Logger.info "wrote chunk #{sequence_number} for table #{basic_table.id}"
          :ok
        err -> err
      end
    rescue
      err ->
        push(job, basic_table, sequence_number, chunk)
        Logger.error "retrying chunk #{sequence_number} for table #{basic_table.id}"
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