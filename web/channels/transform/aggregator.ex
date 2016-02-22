defmodule Transform.Channels.Transform.Aggregator do
  use GenServer
  alias Phoenix.Channel


  def init(_) do
    {:ok, %{
      counters: %{},
      chunks: 0
    }}
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

  def handle_cast({:aggregate, socket, chunk_agg}, state) do
    counters = aggregate(chunk_agg, state.counters)

    state = put_in(state[:counters], counters)

    Channel.push(socket, "dataset:aggregate", to_serializable(state.counters))

    {:noreply, state}
  end

  def push(pid, socket, aggregate) do
    GenServer.cast(pid, {:aggregate, socket, aggregate})
  end
end