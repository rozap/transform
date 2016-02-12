defmodule Transform.Channels.Transform.Aggregator do
  use GenServer
  alias Phoenix.Channel


  def init(_) do
    {:ok, %{
      counters: %{},
      chunks: 0
    }}
  end

  def aggregate(chunk, counters) do

    Enum.reduce(chunk, counters, fn {col_name, col_counts}, acc ->
      Enum.reduce(col_counts, acc, fn {col_value, value_count}, acc ->
        path = [col_name, col_value]
        acc = case acc[col_name] do
          nil -> put_in(acc, [col_name], [])
          _ -> acc
        end
        acc = case Enum.find(acc[col_name], fn {v, _} -> v == col_value end) do
          nil ->
            current_counts = Dict.get(acc, col_name)
            Dict.put(acc, col_name, [{col_value, 0} | current_counts])
          _ ->
            acc
        end

        counts = Dict.get(acc, col_name)
        updated_counts = Enum.map(counts, fn
          {^col_value, current} -> {col_value, current + value_count}
          any -> any
        end)

        Dict.put(acc, col_name, updated_counts)
      end)
    end)
    |> Enum.map(fn {col_name, counts} ->
      slice = counts
      |> Enum.sort(fn {_, a}, {_, b} -> a > b end)
      |> Enum.take(100)

      {col_name, slice}
    end)
    |> Enum.into(%{})
  end

  def to_serializable(counters) do
    counters
    |> Enum.map(fn {k, v} -> {k, Enum.into(v, %{})} end)
    |> Enum.into(%{})
  end

  def handle_cast({:aggregate, socket, chunk}, state) do
    counters = aggregate(chunk, state.counters)

    state = put_in(state[:counters], counters)

    Channel.push(socket, "dataset:aggregate", to_serializable(state.counters))

    {:noreply, state}
  end

  def push(pid, socket, aggregate) do
    GenServer.cast(pid, {:aggregate, socket, aggregate})
  end
end