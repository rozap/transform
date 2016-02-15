defmodule Transform.BasicTable.Worker do
  use GenServer
  require Logger
  alias Transform.Executor.Worker
  alias Transform.Api.BasicTable
  alias Transform.Chunk
  alias Transform.Repo
  alias Transform.BlobStore

  def start_link(args) do
    # called in supervising process
    GenServer.start_link(__MODULE__, args, [])
  end

  def init([id: id]) do
    # called in the context of the actual genserver once it's started
    :pg2.join(__MODULE__, self)
    Logger.info("Started #{inspect __MODULE__} #{id}")
    {:ok, %{
      uploads: %{},
      id: id
    }}
  end



  def handle_cast({:push, job, basic_table, {sequence_number, chunk}}, state) do
    location = BlobStore.write_basic_table_chunk!(job.dataset, chunk)

    case Repo.insert(%Chunk{
      basic_table_id: basic_table.id,
      sequence_number: sequence_number,
      location: location
    }) do
      {:ok, entry} ->
        Worker.push(job, basic_table, entry)
      {:error, reason} ->
        Logger.error("Failed to persist chunk! #{reason}")
    end


    {:noreply, state}
  end

  def push(job, basic_table, chunk) do
    case Enum.take_random(:pg2.get_members(__MODULE__), 1) do
      [] -> raise ArgumentError, message: "No members of pg2 group #{inspect __MODULE__}"
      [someone] -> GenServer.cast(someone, {:push, job, basic_table, chunk})
    end
  end
end