defmodule Transform.Channels.Transform do
  use Phoenix.Channel
  require Logger
  alias Transform.Executor

  def join("transform:" <> dataset_id, _message, socket) do
    Logger.info("Joining transform #{dataset_id}")
    socket = assign(socket, :dataset_id, dataset_id)

    Executor.transform(dataset_id, [])
    Executor.listen(dataset_id)

    {:ok, socket}
  end


  def handle_in("transform", %{"transforms" => transforms}, socket) do
    IO.puts "Adding transforms #{inspect transforms}"
    Executor.transform(socket.assigns.dataset_id, transforms)
    {:reply, :ok, socket}
  end

  def handle_in(what, why, socket) do
    IO.puts "what #{what} #{inspect why}"
    {:reply, :ok, socket}
  end

  def handle_info({:transformed, result}, socket) do
    push(socket, "dataset:chunk", result)
    {:noreply, socket}
  end

  def handle_info({:header, header}, socket) do
    push(socket, "dataset:header", %{"header" => header})
    {:noreply, socket}
  end
end