defmodule InterpreterTest do
  use ExUnit.Case
  import TestHelpers
  alias Transform.Interpreter

  # test "can interpret a single function" do
  #   [
  #     "rename",
  #     [],
  #     [
  #       [
  #         "parse_datetime",
  #         [],
  #         [
  #           [
  #             "concat",
  #             [],
  #             ["__DATUM__", "date_col", " ", "time_col", "datetime"]
  #           ],
  #           "datetime"
  #         ]
  #       ],
  #       "datetime",
  #       "sometime"
  #     ]
  #   ]
  # end


  # test "can interpret a basic thing" do

  #   pipeline = read!("interpreter/concat.json")
  #   |> Poison.decode!

  #   header = %BasicTable{columns: ["name", "date_col", "time_col"]}
  #   send Executor, {:header, "ff", header}

  #   Executor.listen("ff")
  #   Executor.transform("ff", pipeline)

  #   send Executor, {:chunk, "ff", [
  #     ["some name", "2016-02-03", "7:27:29"],
  #     ["another name", "2016-02-04", "9:27:29"]

  #   ]}

  #   receive do
  #     {:transformed, result} ->
  #       assert result ==  %{
  #         errors: [],
  #         transformed: [
  #           %{"name" => "another name", "sometime" => "2016-02-04 9:27:29"},
  #           %{"name" => "some name", "sometime" => "2016-02-03 7:27:29"}
  #         ]
  #       }
  #   after 20 ->
  #     raise ArgumentError, message: "never received chunk response"
  #   end

  # end
end