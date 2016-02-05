defmodule Transform.Interpreter.Ops do

  alias Transform.BasicTableServer.BasicTable


  def concat({header, row}, n0, n1, n2) do
    {:ok, {header, row}}
  end

  # defmacro concat do
  #   quote do
  #     IO.inspect header

  #     {:ok, :ok}
  #   end
  # end



  def parse_datetime() do
    {:ok, :ok}
  end

  def rename() do
    {:ok, :ok}
  end
end