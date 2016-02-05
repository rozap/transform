defmodule InterpreterTest do
  use ExUnit.Case
  import TestHelpers
  alias Transform.Interpreter
  alias Transform.Executor
  alias Transform.BasicTableServer.BasicTable


  test "can interpret a basic thing" do

    pipeline = read!("interpreter/concat.json")
    |> Poison.decode!

    header = %BasicTable{columns: ["name", "date_col", "time_col"]}
    send Executor, {:header, "ff", header}

    Executor.listen("ff")
    Executor.transform("ff", pipeline)

    send Executor, {:chunk, "ff", [
      ["some name", "2016-02-03", "7:27:29"],
      ["another name", "2016-02-04", "9:27:29"]

    ]}


    receive do
      message -> IO.inspect message
    after 20 -> raise ArgumentError, message: "never received chunk response"
    end

    IO.puts "Done..."
  end
end