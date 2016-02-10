defmodule Transform.Channels.Transform do
  use Phoenix.Channel
  require Logger
  alias Transform.Compiler
  alias Transform.Channels.Transform.Aggregator

  # Never show more than N rows to the user
  @threshold 512

  def join("transform:" <> dataset_id, _message, socket) do
    Logger.info("Joining transform #{dataset_id}")
    socket = assign(socket, :dataset_id, dataset_id)

    Compiler.compile(dataset_id, [])
    :pg2.create(dataset_id)
    :pg2.join(dataset_id, self)

    {:ok, ag_pid} = GenServer.start_link(Aggregator, [])

    socket = assign(socket, :aggregator, ag_pid)

    {:ok, socket}
  end


  def handle_in("transform", %{"transforms" => transforms}, socket) do
    Compiler.compile(socket.assigns.dataset_id, transforms)
    {:reply, :ok, socket}
  end


  def handle_info({:transformed, basic_table, result}, socket) do
    upload = basic_table.upload
    current = Dict.get(socket.assigns, upload, 0)
    socket = assign(socket, upload, current + length(result.transformed))
    seen = Dict.get(socket.assigns, upload)
    if seen < @threshold do
      push(socket, "dataset:transform", %{result: result.transformed})
    end

    case result.errors do
      [] -> :ok
      errors ->
        Logger.info("Got error #{inspect errors}")
        push(socket, "dataset:errors", %{result: result.errors})
    end


    Aggregator.push(socket.assigns.aggregator, socket, result.transformed)

    {:noreply, socket}
  end

end