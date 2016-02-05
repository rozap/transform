defmodule Transform.Interpreter do

  def to_ast([func, meta, args], transformable) do
    func_name = String.to_atom(func)

    {{:., [], [
      {:__aliases__, [alias: false], [Transform.Interpreter.Ops]},
      func_name
    ]}, [], [transformable | Enum.map(args, fn arg ->
      to_ast(arg, transformable)
    end)]}
  end

  def to_ast(atomic, _) do
    atomic
  end



end


