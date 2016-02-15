defmodule Transform.Channels.Transform do
  use Phoenix.Channel
  require Logger
  alias Transform.Compiler
  alias Transform.Channels.Transform.Aggregator

  # Never show more than N rows to the user
  @threshold 2048

  def join("transform:" <> dataset_id, _message, socket) do
    Logger.info("Joining transform #{dataset_id}")
    socket = assign(socket, :dataset_id, dataset_id)

    :pg2.create(dataset_id)
    :pg2.join(dataset_id, self)

    {:ok, ag_pid} = GenServer.start_link(Aggregator, [])

    socket = socket
    |> assign(:aggregator, ag_pid)
    |> assign(:seen, 0)

    {:ok, socket}
  end

  def handle_in("transform", %{"transforms" => transforms}, socket) do
    Compiler.compile(socket.assigns.dataset_id, transforms)
    {:reply, :ok, socket}
  end

  defp push_result(socket, result) do
    case result.errors do
      [] -> :ok
      errors ->
        Logger.info("Got error #{inspect errors}")
        push(socket, "dataset:errors", %{result: result.errors})
    end

    Aggregator.push(socket.assigns.aggregator, socket, result.aggregate)

    {:noreply, socket}
  end

  defp push_progress(socket, result) do
    chunk_size = Transform.Api.BasicTable.chunk_size
    push(socket, "dataset:progress", %{rows: result.chunk.sequence_number * chunk_size})
  end

  def handle_info({:transformed, basic_table, result}, %{assigns: %{seen: seen}} = socket) when seen < @threshold do
    socket = assign(socket, :seen, seen + length(result.transformed))

    push(socket, "dataset:transform", %{result: result.transformed})
    push_progress(socket, result)
    push_result(socket, result)
  end

  def handle_info({:transformed, basic_table, result}, socket) do
    seen = socket.assigns.seen
    socket = assign(socket, :seen, seen + length(result.transformed))
    push_progress(socket, result)
    push_result(socket, result)
  end

end