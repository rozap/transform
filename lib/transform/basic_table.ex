defmodule Transform.BasicTableSupervisor do
  require Logger
  import Supervisor.Spec
  use Supervisor


  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    :pg2.create(Transform.BasicTable.Worker)
    count = Application.get_env(:transform, :workers)[:basic_table][:count]
    children = Enum.map(1..count, fn i ->
      id = String.to_atom("basic_table_worker_#{i}")
      worker(Transform.BasicTable.Worker, [[id: id]], id: id)
    end)

    supervise(children, strategy: :one_for_one, name: __MODULE__)
  end

end