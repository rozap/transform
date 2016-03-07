defmodule Mix.Tasks.Ship do
  use Mix.Task

  def run(_) do
    version = Transform.Mixfile.project[:version]

    path = Path.join([__DIR__, "..", "package.json"])
    package_json = path
    |> File.read!
    |> Poison.decode!
    |> Dict.put("version", version)
    |> Poison.encode!(pretty: true)

    File.write!(path, package_json)

    Mix.shell.info("Version is #{version}")
  end
end