defmodule Transform.Channels.Transform do
  use Phoenix.Channel
  require Logger
  alias Transform.Compiler
  alias Transform.JobTrigger
  alias Transform.Channels.Transform.Aggregator
  alias Transform.Job
  alias Transform.Repo
  import Ecto.Query

  # Never show more than N rows to the user
  @threshold 16

  def join("transform:" <> dataset_id, _message, socket) do
    Logger.info("Joining transform #{dataset_id}")
    socket = assign(socket, :dataset_id, dataset_id)

    :pg2.create(dataset_id)
    :ok = :pg2.join(dataset_id, self)
    {:ok, ag_pid} = GenServer.start_link(Aggregator, [])

    socket = socket
    |> assign(:aggregator, ag_pid)
    |> assign(:seen, 0)

    JobTrigger.bind

    {:ok, socket}
  end

  def handle_in("transform", %{"transforms" => transforms}, socket) do
    Logger.info("Compile #{inspect transforms}")
    case Compiler.compile(socket.assigns.dataset_id, transforms) do
      {:ok, {job, basic_table, chunks}} ->
        JobTrigger.trigger(job, basic_table, chunks)
      {:error, reason} ->
        Logger.error("Error while compiling: #{inspect reason}")
    end

    {:reply, :ok, socket}
  end

  defp push_result(socket, result) do
    Aggregator.push(
      socket.assigns.aggregator, socket,
      result.chunk.sequence_number, result.aggregate
    )

    {:noreply, socket}
  end

  defp push_progress(socket, stage, result) do
    chunk_size = Transform.Api.BasicTable.chunk_size
    push(socket, "dataset:progress", %{
      sequenceNumber: result.chunk.sequence_number,
      errors: result.errors,
      stage: stage
    })

    {:noreply, socket}
  end

  def handle_info({:transformed, basic_table, result}, %{assigns: %{seen: seen}} = socket) when seen < @threshold do
    socket = assign(socket, :seen, seen + length(result.transformed))

    push(socket, "dataset:transform", %{result: result.transformed})
    push_progress(socket, "transform", result)
    push_result(socket, result)
  end

  def handle_info({:transformed, basic_table, result}, socket) do
    seen = socket.assigns.seen
    socket = assign(socket, :seen, seen + length(result.transformed))
    push_progress(socket, "transform", result)
    push_result(socket, result)
  end

  def handle_info({:basic_table_chunk_written, result}, socket) do
    push_progress(socket, "extract", result)
  end

end