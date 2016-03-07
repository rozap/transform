defmodule Transform do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false



    children = [
      supervisor(Transform.Endpoint, []), # Phoenix's HTTP Listener.
      supervisor(Transform.Repo, []), # Postgres connection.
      worker(Transform.ExecutorSupervisor, []), # Where we will run our transforms.
      supervisor(Transform.BasicTableSupervisor, []), # Creates basic table from chunks.
      supervisor(Transform.Compiler, []), # Takes an AST and transforms it into a function
      supervisor(Transform.Herder, []),
      supervisor(Transform.Zookeeper, []),
      supervisor(Transform.Metrics, []),
      supervisor(Transform.JobTrigger, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Transform.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Transform.Endpoint.config_change(changed, removed)
    :ok
  end
end
