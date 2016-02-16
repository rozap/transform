# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :transform, Transform.Endpoint,
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "7q2bPhBpVu+hgySi+bxY+NtTQj7kdjkuxGUZ6DXH1w5+QJl8xk0ZA03t18ltKk8/",
  render_errors: [accepts: ~w(html json)],
  pubsub: [name: Transform.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"

# Configure phoenix generators
config :phoenix, :generators,
  migration: true,
  binary_id: false

config :transform, Transform.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "transform_dev",
  hostname: "localhost",
  pool_size: 10

config :transform, :zookeeper,
  address: :"localhost",
  port: 2181

config :transform, :workers,
  executor: [
    count: 8,
    high_water_mark: 8
  ],
  basic_table: [
    count: 8,
    high_water_mark: 8
  ]

config :transform, :herder,
  interval: 60,
  max_attempts: 4
