defmodule Transform.Mixfile do
  use Mix.Project

  def project do
    [app: :transform,
     version: "0.0.13",
     elixir: "~> 1.3",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases,
     deps: deps]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {Transform, []},
     applications: [
      :phoenix,
      :phoenix_html,
      :cowboy,
      :logger,
      :gettext,
      :phoenix_ecto,
      :postgrex,
      :erlzk,
      :workex,
      :erlcloud,
      :tzdata,
      :statistics,
      :uuid,
      :calendar,
      :spacesaving,
      :csv
    ]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [{:phoenix, "~> 1.1.4"},
     {:postgrex, ">= 0.0.0"},
     {:workex, "~> 0.10.0"},
     {:phoenix_ecto, "~> 2.0"},
     {:phoenix_html, "~> 2.4"},
     {:phoenix_live_reload, "~> 1.0", only: :dev},
     {:gettext, "~> 0.9"},
     {:cowboy, "~> 1.0"},
     {:uuid, "~> 1.1"},
     {:csv, "~> 1.2.3"},
     {:poolboy, "~> 1.5"},
     {:calendar, "~> 0.12.4"},
     {:erlzk, "~> 0.6.1"},
     {:erlcloud, git: "https://github.com/erlcloud/erlcloud", tag: "0.13.8"},
     {:spacesaving, "~> 0.0.2"},
     {:statistics, "~> 0.4.0"},
     {:exrm, "~> 1.0.2"}
   ]
  end

  # Aliases are shortcut or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    ["ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
     "ecto.reset": ["ecto.drop", "ecto.setup"]]
  end
end
