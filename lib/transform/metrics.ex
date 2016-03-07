defmodule Transform.Metrics do
  use GenServer
  require Logger

  @percentile 95
  @interval 2000

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(opts) do
    :timer.send_interval(@interval, self, :tick)
    {:ok, %{chunk_deltas: []}}
  end

  def handle_cast({:chunk, chunk}, %{chunk_deltas: deltas} = state) do

    inserted_at = Ecto.DateTime.to_erl(chunk.inserted_at)

    diff = chunk.completed_at
    |> Ecto.DateTime.to_erl
    |> Calendar.NaiveDateTime.diff(inserted_at)

    diff = case diff do
      {:ok, 0, 0, :same_time} -> 0
      {:ok, seconds, us, :after} ->
        seconds + (us / 1000.0)
      {:ok, _, _, :before} ->
        Logger.warn("Time travelling chunk?")
        0
    end
    state = %{state | chunk_deltas: [diff | deltas]}
    {:noreply, state}
  end

  def handle_info(:tick, %{chunk_deltas: deltas} = state) do

    case deltas do
      [] -> :ok
      _ ->
        cps = length(deltas) / (@interval / 1000)
        perc = Statistics.percentile(deltas, @percentile)
        Logger.info("Chunk #{@percentile}% percentile takes #{perc}, #{cps} chunks/s")

    end
    {:noreply, %{state | chunk_deltas: []}}
  end

  def chunk_finished(chunk) do
    GenServer.cast(__MODULE__, {:chunk, chunk})
  end
end