defmodule Transform.Transformations do


  @falses ["0", "f", "false", "n", "no", "off"]
  @trues ["1", "t", "true", "y", "yes", "on"]

  Enum.each(@falses, fn value ->
    def parse_checkbox(_, unquote(value)), do: {:ok, false}
  end)
  Enum.each(@trues, fn value ->
    def parse_checkbox(_, unquote(value)), do: {:ok, true}
  end)
  def parse_checkbox(_, value), do: {:ok, value}

  def ferd("MAKE", "FORD"), do: {:ok, "FERD"}
  def ferd(_, value), do: {:ok, value}

end