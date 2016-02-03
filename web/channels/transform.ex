defmodule Transform.Channels.Transform do
  use Phoenix.Channel
  require Logger
  alias Transform.Executor

  def join("transform:" <> dataset_id, _message, socket) do
    Logger.info("Joining transform #{dataset_id}")
    assign(socket, :dataset_id, dataset_id)

    Executor.transform(dataset_id, [])
    Executor.listen(dataset_id)

    {:ok, socket}
  end


  defp to_pipeline(transforms) do
    []
  end

  def handle_in("transform", %{"transforms" => transforms}, socket) do

    pipeline = to_pipeline(transforms)
    Executor.transform(socket.assign.dataset_id, pipeline)

    {:reply, :ok, socket}
  end

  def handle_info({:transformed, chunk}, socket) do
    Logger.info("Got chunk result! #{inspect chunk}")
    Enum.each(chunk, fn row -> 
      push(socket, "dataset:row", %{"row" => row})
    end)
    {:noreply, socket}
  end

  def handle_info({:header, header}, socket) do
    push(socket, "dataset:header", %{"header" => header})
    {:noreply, socket}
  end
end