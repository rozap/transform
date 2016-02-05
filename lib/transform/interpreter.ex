defmodule Transform.Interpreter do

  def to_ast([func, meta, args]) do
    func_name = String.to_atom(func)


    {:fn, [],
     [{:->, [],
       [
        [{{:header, [], Elixir}, {:row, [], Elixir}}],
          {{:., [], [
            {:__aliases__, [alias: false], [Transform.Interpreter.Ops]},
            func_name
          ]}, [], [{{:header, [], Elixir}, {:row, [], Elixir}} | Enum.map(args, fn arg -> to_ast(arg) end)]}]}]}

  end

  def to_ast(atomic) do
    atomic
  end



end


