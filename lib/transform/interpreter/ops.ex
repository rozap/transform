defmodule Transform.Interpreter.Ops do
  alias Transform.BasicTableServer.BasicTable

  defmacro map(result, expr) do
    quote do
      case unquote(result) do
        :ok -> unquote(expr)
        errors -> errors
      end
    end
  end

  def concat({:ok, datum}, c0, sep, c1, new_name) do
    v0 = Map.get(datum, c0)
    v1 = Map.get(datum, c1)

    new_value = v0 <> sep <> v1

    transformed = datum
    |> Map.drop([c0, c1])
    |> Map.put(new_name, new_value)

    {:ok, transformed}
  end


  defp check_key_use(dest, name) do
    if Map.has_key?(dest, name) do
      {:error, %{
        "name" => "unpivot",
        "reason" => "destination_column_taken",
        "args" => [name]
      }}
    else
      :ok
    end
  end

  def unpivot({:ok, datum}, col_dest, val_dest, columns) do
    {to_dup, to_keep} = Map.split(datum, columns)

    with :ok <- check_key_use(datum, col_dest),
      :ok <- check_key_use(datum, val_dest) do

      unpivoted = columns
      |> Enum.map(fn value ->
        to_keep
        |> Map.put(col_dest, value)
        |> Map.put(val_dest, to_dup[value])
      end)
      {:ok, unpivoted}
    end
  end


  def lookup({:ok, datum}, col_name, lookup_table) do
    value = Map.get(datum, col_name)
    new_value = Enum.find_value(lookup_table, value, fn
      [^value, to_value] -> to_value
      [_, _] -> false
    end)
    {:ok, Map.put(datum, col_name, new_value)}
  end


  def rename({:ok, datum}, from, to) do
    value = Map.get(datum, from)
    transformed = datum
    |> Map.drop([from])
    |> Map.put(to, value)
    {:ok, transformed}
  end

  def drop({:ok, datum}, colname, _wat) do
    transformed = datum
    |> Map.delete(colname)

    {:ok, transformed}
  end
end


