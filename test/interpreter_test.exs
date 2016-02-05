defmodule InterpreterTest do
  use ExUnit.Case
  import TestHelpers
  alias Transform.Interpreter
  alias Transform.Executor
  alias Transform.BasicTableServer.BasicTable


  test "can interpret a basic thing" do

    pipeline = read!("interpreter/concat.json")
    |> Poison.decode!

    header = %BasicTable{columns: ["a", "b", "c"]}
    send Executor, {:header, "ff", header}

    Executor.listen("ff")
    Executor.transform("ff", pipeline)

    send Executor, {:chunk, "ff", [
      ["a_val", "b_val", "c_val"]
    ]}


    receive do
      message -> IO.inspect message
    after 20 -> raise ArgumentError, message: "never received chunk response"
    end

    IO.puts "Done..."
  end
end