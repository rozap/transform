defmodule Transform.Channels.Transform.Aggregator do
  use GenServer
  alias Phoenix.Channel

  def init(_) do
    {:ok, %{
      counters: %{}
    }}
  end

  def handle_cast({:transformed, socket, transformed}, state) do
    counters = Enum.reduce(transformed, state.counters, fn row, acc ->
      Enum.reduce(row, acc, fn {colname, value}, acc ->
        path = [colname, value]
        acc = case acc[colname] do
          nil -> put_in(acc, [colname], %{})
          _ -> acc
        end
        acc = case acc[colname][value] do
          nil -> put_in(acc, path, 0)
          _ -> acc
        end

        current = get_in(acc, path)
        put_in(acc, path, current + 1)
      end)
    end)

    state = put_in(state[:counters], counters)
    Channel.push(socket, "dataset:aggregate", state.counters)

    {:noreply, state}
  end

  def push(pid, socket, transformed) do
    GenServer.cast(pid, {:transformed, socket, transformed})
  end
end