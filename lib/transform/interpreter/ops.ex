defmodule Transform.Interpreter.Ops do

  alias Transform.BasicTableServer.BasicTable

  def concat({:ok, {header, row}}, n0, n1, n2) do
    IO.inspect header
    IO.inspect row

    {:ok, {header, row}}
  end


  def parse_datetime({:ok, {header, row}}) do
    {:ok, header, row}
  end

  def rename({:ok, {header, row}}) do
    {:ok, header, row}
  end
end