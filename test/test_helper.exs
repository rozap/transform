ExUnit.start

defmodule TestHelpers do
  def fixture!(name) do
    File.stream!("#{__DIR__}/fixtures/#{name}", [:read], :line)
  end

  def read!(name) do
    File.read!("#{__DIR__}/fixtures/#{name}")
  end

end

Mix.Task.run "ecto.create", ~w(-r Transform.Repo --quiet)
Mix.Task.run "ecto.migrate", ~w(-r Transform.Repo --quiet)
Ecto.Adapters.SQL.begin_test_transaction(Transform.Repo)

