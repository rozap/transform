defmodule Transform.Interpreter.Ops do

  alias Transform.BasicTableServer.BasicTable


  def concat({:ok, datum}, c0, sep, c1, new_name) do
    v0 = Dict.get(datum, c0)
    v1 = Dict.get(datum, c1)

    new_value = v0 <> sep <> v1

    transformed = datum
    |> Dict.drop([c0, c1])
    |> Dict.put(new_name, new_value)

    {:ok, transformed}
  end

  def lookup({:ok, datum}, col_name, lookup_table) do
    value = Dict.get(datum, col_name)
    new_value = Enum.find_value(lookup_table, value, fn
      [^value, to_value] -> to_value
      [_, _] -> false
    end)
    {:ok, Dict.put(datum, col_name, new_value)}
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


