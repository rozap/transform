defmodule Transform.Channels.Transform.Aggregator do
  use GenServer
  alias Phoenix.Channel


  def init(_) do
    {:ok, init_state}
  end

  defp init_state do
    %{
      counters: %{},
      job_id: nil,
      chunks: 0
    }
  end

  def aggregate(chunk_agg, counters) do
    Enum.reduce(chunk_agg, counters, fn {colname, counter}, counters ->
      case Map.get(counters, colname) do
        nil ->
          Map.put(counters, colname, counter)
        existing ->
          merged = Spacesaving.merge(existing, counter)
          Map.put(counters, colname, merged)
      end
    end)
  end

  def to_serializable(counters) do
    counters
    |> Enum.map(fn {colname, counter} ->
      top_els = Spacesaving.top(counter, 64)
      |> Enum.into(%{})

      {colname, top_els}
    end)
    |> Enum.into(%{})
  end

  defp update_state(state, socket, seq, partial) do
    counters = aggregate(partial, state.counters)

    state = put_in(state[:counters], counters)

    Channel.push(socket, "dataset:aggregate", %{
      sequenceNumber: seq,
      histograms: to_serializable(state.counters)
    })
    state
  end

  def handle_cast({:aggregate, socket, seq, partial, job_id}, %{job_id: job_id} = state) do
    {:noreply, update_state(state, socket, seq, partial)}
  end

  def handle_cast({:aggregate, socket, seq, partial, job_id}, state) do
    state = init_state
    |> Dict.put(:job_id, job_id)
    |> update_state(socket, seq, partial)

    {:noreply, state}
  end

  def push(pid, socket, sequence_number, partial, job_id) do
    GenServer.cast(pid, {:aggregate, socket, sequence_number, partial, job_id})
  end
end