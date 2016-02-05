defmodule Transform.Interpreter.Ops do

  alias Transform.BasicTableServer.BasicTable


  def concat({:ok, datum}, c0, sep, c1, new_name) do

    IO.puts "Concat #{c0} #{c1} #{inspect datum}"

    v0 = Dict.get(datum, c0)
    v1 = Dict.get(datum, c1)

    new_value = v0 <> sep <> v1

    transformed = datum
    |> Dict.drop([c0, c1])
    |> Dict.put(new_name, new_value)

    {:ok, transformed}
  end


  defp as_dt(nil), do: {:error, "no column named that"}
  defp as_dt(value) do
    {:ok, value}
  end

  def parse_datetime({:ok, datum}, column_name) do
    case as_dt(datum[column_name]) do
      {:error, _} = e -> e
      {:ok, parsed} -> {:ok, Dict.put(datum, column_name, parsed)}
    end
  end

  def rename({:ok, datum}, from, to) do
    value = Dict.get(datum, from)
    transformed = datum
    |> Dict.drop([from])
    |> Dict.put(to, value)
    {:ok, transformed}
  end
end