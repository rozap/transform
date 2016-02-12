defmodule Transform.BasicTable.Worker do
  use GenServer
  require Logger
  alias Transform.Executor.Worker
  alias Transform.Api.BasicTable
  alias Transform.Chunk
  alias Transform.Repo

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

  def write!(ds_id, chunk) do
    path = "/tmp/#{ds_id}_chunk_#{UUID.uuid4}.csv"
    device = File.open!(path, [:write])

    chunk
    |> CSV.encode
    |> Enum.each(fn line -> IO.binwrite(device, line) end)

    File.close(device)
    path
  end


  def handle_call({:push, dataset_id, basic_table, {sequence_number, chunk}}, _, state) do
    # %BasicTable{columns: columns, upload: upload_id} = basic_table

    ## Write to persistent store

    location = write!(dataset_id, chunk)

    case Repo.insert(%Chunk{
      basic_table_id: basic_table.id,
      sequence_number: sequence_number,
      location: location
    }) do
      {:ok, entry} ->
        Worker.push(dataset_id, basic_table, entry)
      {:error, reason} ->
        Logger.error("Failed to persist chunk! #{reason}")
    end


    {:reply, :ok, state}
  end

  def push(dataset_id, basic_table, chunk) do
    case Enum.take_random(:pg2.get_members(__MODULE__), 1) do
      [] -> raise ArgumentError, message: "No members of pg2 group #{inspect __MODULE__}"
      [someone] -> GenServer.call(someone, {:push, dataset_id, basic_table, chunk})
    end
  end
end