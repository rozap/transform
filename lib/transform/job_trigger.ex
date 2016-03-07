defmodule Transform.JobTrigger do
  use GenEvent
  require Logger
  alias Transform.Executor.Worker
  alias Transform.Repo
  alias Transform.Job
  alias Transform.BasicTable
  import Ecto.Query

  def start_link do
    GenEvent.start_link(name: __MODULE__)
  end

  defp send_chunks_for(basic_table) do
    IO.puts "Sending chunks for #{inspect basic_table}"
  end

  def handle_event({:trigger, job, basic_table, chunks}, parent) do

    Enum.each(chunks, fn chunk ->
      Worker.push(job, basic_table, chunk)
    end)
    {:ok, parent}
  end

  def bind do
    GenEvent.add_handler(__MODULE__, __MODULE__, self)
  end

  def trigger(_, nil, []) do
    Logger.error("Ignoring job trigger because there is no existing job")
    :ok
  end

  def trigger(job, basic_table, chunks) do
    GenEvent.notify(__MODULE__, {:trigger, job, basic_table, chunks})
  end
end