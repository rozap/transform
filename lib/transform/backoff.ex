defmodule Transform.Backoff do
  require Logger

  defp wait_then(func, timeout, tag) do
    Logger.warn("Waiting for #{timeout} to execute #{tag}")
    :timer.sleep(timeout)
    func.()
  end

  defp try_for(func, maximum, waited, _, _)
    when maximum != :infinity and waited > maximum do
    {:error, :timeout}
  end
  defp try_for(func, maximum, waited, wait, tag) do
    case wait_then(func, wait, tag) do
      {:error, :no_worker} ->
        try_for(func, maximum, waited + wait, wait * 2, tag)
      res ->
        res
    end
  end
  defp try_for(func, maximum, tag) do
    try_for(func, maximum, 0, 50, tag)
  end

  defp build_push_func(group_name, payload) do
    fn ->
      :pg2.get_members(group_name)
      |> Enum.shuffle
      |> Enum.reduce_while(:no_worker, fn worker, acc ->
        case Workex.push_ack(worker, payload) do
          :ok ->
            # This means a worker has accepted the payload
            {:halt, :found_worker}
          {:error, :max_capacity} ->
            # Try the next worker, maybe they will accept it
            {:cont, acc}
          err -> err
        end
      end)
    end
  end

  def try_until(group_name, payload, timeout) do
    push_func = build_push_func(group_name, payload)
    case push_func.() do
      :found_worker -> :ok
      :no_worker -> try_for(push_func, 10_000, "Push to #{group_name}")
      err -> err
    end
  end

end