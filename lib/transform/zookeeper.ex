defmodule Transform.Zookeeper do
  use GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init(args) do
    Process.flag(:trap_exit, true)

    base_path = "/com.socrata/soda/services/transform"
    state = %{
      zk: nil,
      base_path: base_path,
      path: make_path(base_path, UUID.uuid4)
    }
    |> connect!
    |> start_net_kernel!
    |> add_self!
    |> add_nodes!
    {:ok, state}
  end

  def connect!(state) do
    Logger.info("Zk connect attempt")
    {:ok, pid} = :erlzk.connect(
      [{
        Application.get_env(:transform, :zookeeper)[:address],
        Application.get_env(:transform, :zookeeper)[:port]
      }],
      30000,
      [
        {:chroot, "/"},
        {:monitor, self}
      ]
    )
    %{state | zk: pid}
  end

  defp make_path(base_path, child), do: "#{base_path}/#{child}"

  defp start_net_kernel!(state) do
    case :inet.getif do
      {:ok, [{addr, _, _} | _]} ->
        address = case addr do
          {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
        end
        name = System.get_env("NODE_NAME") || "seed"
        node = String.to_atom(name <> "@" <> address)
        Logger.info("I'm node #{node}")
        :net_kernel.start([node, :longnames])
    end
    state
  end

  defp add_self!(state) do

    identifier = %{
      name: Node.self
    }
    |> Poison.encode!

    :erlzk.create(state.zk, state.base_path)
    case :erlzk.create(state.zk, state.path) do
      {:ok, path} ->
        Logger.info("I am #{identifier} @ #{path}")
      {:error, reason} ->
        raise RuntimeError, message: "Failed to put path in zk #{reason}"
    end
    case :erlzk.set_data(state.zk, state.path, identifier) do
      {:ok, _} ->
        :ok
      {:error, reason} ->
        raise RuntimeError, message: "Failed to put data in zk #{reason}"
    end

    state
  end


  defp connect_to(state, children) do
    Enum.each(children, fn child ->
      case :erlzk.get_data(
        state.zk,
        make_path(state.base_path, child)
      ) do
        {:ok, {node, _}} ->
          node = node
          |> Poison.decode!
          |> Dict.get("name")

          node = :"#{node}"
          if node != Node.self do
            case Node.ping(node) do
              :pong -> Logger.info("Connected to node #{node}")
              :pang -> Logger.warn("Failed to connect to node #{node}")
            end
          end
        {:error, reason} ->
          Logger.error("Zk get_data on #{child} failed #{reason}")
      end
    end)
  end

  defp add_nodes!(state) do
    case :erlzk.get_children(state.zk, state.base_path) do
      {:ok, children} ->
        connect_to(state, children)
      {:error, reason} ->
        raise RuntimeError, message: "Failed to get zk children #{reason}"
    end

    state
  end

  defp cleanup(state) do
    :erlzk.delete(state.zk, state.path)
  end


  def terminate(reason, state) do
    Logger.warn("Zookeeper is terminating #{inspect reason}")
    cleanup(state)
  end

end