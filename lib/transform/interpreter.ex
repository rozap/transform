defmodule Transform.Interpreter do

  def to_ast([func, meta, args]) do
    func_name = String.to_atom(func)
    {{:., [], [
      {:__aliases__, [alias: false], [Transform.Interpreter.Ops]},
      func_name
    ]}, [], to_args(args)}
  end

  def to_ast(atomic) do
    atomic
  end

  defp to_args([[_, _, _] | _] = args), do: Enum.map(args, fn arg -> to_ast(arg) end)
  defp to_args(["__DATUM__" | tail]) do
    [{{:header, [], Elixir}, {:row, [], Elixir}} | Enum.map(tail, fn arg -> to_ast(arg) end)]
  end

  def wrap([func, meta, args]) do
    func_name = String.to_atom(func)
    {:fn, [],
     [{:->, [],
       [
        [{{:header, [], Elixir}, {:row, [], Elixir}}],
          {{:., [], [
            {:__aliases__, [alias: false], [Transform.Interpreter.Ops]},
            func_name
          ]}, [], to_args(args)}]}]}
  end

  def wrap([]) do
    {:fn, [],
     [{:->, [],
       [[{{:header, [], Elixir}, {:row, [], Elixir}}],
        {{:header, [], Elixir}, {:row, [], Elixir}}]}]}
  end

end