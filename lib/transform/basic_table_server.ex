defmodule Transform.BasicTableServer do
  use GenServer
  require Logger

  defmodule BasicTable do
    defstruct columns: []
  end

  def start_link do
    # called in supervising process
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(args) do
    # called in the context of the actual genserver once it's started
    {:ok, %{
      listeners: %{},
      uploads: %{}
    }}
  end

  def write!(device, row) do
    line = Enum.join(row, ",")
    IO.write(device, "#{line}\n")
  end

  def handle_cast({:listen, dataset_id, pid}, state) do
    pids = Enum.uniq([pid | Dict.get(state.listeners, dataset_id, [])])
    state = put_in(state, [:listeners, dataset_id], pids)
    {:noreply, state}
  end

  def handle_cast({:push, dataset_id, upload, chunk}, state) do
    pids = state.listeners[dataset_id] || []

    {state, chunk} = case get_in(state, [:uploads, dataset_id, upload]) do
      nil ->
        [header | rest] = chunk
        bt = %BasicTable{columns: header}

        Enum.each(pids, fn pid -> send pid, {:header, dataset_id, bt} end)

        cache = File.open!("/tmp/#{upload}.csv", [:append])
        write!(cache, header)

        ds_uploads = Dict.get(state.uploads, dataset_id, %{})

        state = state
        |> put_in([:uploads, dataset_id], ds_uploads)
        |> put_in([:uploads, dataset_id, upload], {cache, bt})
        {state, rest}
      _ -> {state, chunk}
    end

    {cache, basic_table} = get_in(state, [:uploads, dataset_id, upload])

    # Enum.each(chunk, fn row -> write!(cache, row) end)

    Enum.each(pids, fn pid -> send pid, {:chunk, dataset_id, chunk} end)

    {:noreply, state}
  end

  def listen(dataset_id) do
    GenServer.cast(__MODULE__, {:listen, dataset_id, self})
  end

  def push(dataset_id, upload, chunk) do
    GenServer.cast(__MODULE__, {:push, dataset_id, upload, chunk})
  end
end