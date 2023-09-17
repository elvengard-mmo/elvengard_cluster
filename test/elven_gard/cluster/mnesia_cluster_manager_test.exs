defmodule ElvenGard.Cluster.MnesiaClusterManagerTest do
  use ExUnit.Case, async: true
  use ElvenGard.Cluster.Testing.ExUnitCluster

  alias ElvenGard.Cluster.MnesiaClusterManager

  @timeout 5_000

  ## Setup

  setup %{nodes: nodes} do
    # Remove logs
    :rpc.multicall(nodes, Logger, :configure, [[level: :error]])
    :ok
  end

  ## Tests

  @nodes 3
  cluster "manually connect", %{nodes: nodes} do
    [node1, node2, node3] = nodes

    # Start MnesiaClusterManager
    :ok = multi_spawn_request!(nodes, MnesiaClusterManager)

    # No node is connected
    {result, []} = :rpc.multicall(nodes, MnesiaClusterManager, :connected?, [])
    assert [false, false, false] = result

    {result, []} = :rpc.multicall(nodes, :mnesia, :system_info, [:running_db_nodes])
    assert [^node1] = Enum.at(result, 0)
    assert [^node2] = Enum.at(result, 1)
    assert [^node3] = Enum.at(result, 2)

    # Connect node2 to node 1
    {result, []} = :rpc.multicall([node2], MnesiaClusterManager, :connect, [node1])
    assert [:ok] = result

    {result, []} = :rpc.multicall(nodes, MnesiaClusterManager, :connected?, [])
    assert [true, true, false] = result

    {result, []} = :rpc.multicall(nodes, :mnesia, :system_info, [:running_db_nodes])
    assert [^node2, ^node1] = Enum.at(result, 0)
    assert [^node1, ^node2] = Enum.at(result, 1)
    assert [^node3] = Enum.at(result, 2)

    # Connect node2 to node 1
    {result, []} = :rpc.multicall([node3], MnesiaClusterManager, :connect, [node2])
    assert [:ok] = result

    {result, []} = :rpc.multicall(nodes, MnesiaClusterManager, :connected?, [])
    assert [true, true, true] = result

    {result, []} = :rpc.multicall(nodes, :mnesia, :system_info, [:running_db_nodes])
    assert [^node3, ^node2, ^node1] = Enum.at(result, 0)
    assert [^node3, ^node1, ^node2] = Enum.at(result, 1)
    assert [^node1, ^node2, ^node3] = Enum.at(result, 2)
  end

  @nodes 1
  cluster "automatically connect raise an error when no master defined", %{nodes: [node1]} do
    # Start MnesiaClusterManager
    opts = [auto_connect: true]
    :ok = multi_spawn_request!([node1], MnesiaClusterManager, opts)

    assert {:badrpc, {:EXIT, {{error, _}, _}}} =
             :rpc.call(node1, MnesiaClusterManager, :connected?, [])

    assert %ArgumentError{message: ":master node option is required when auto_connect is enabled"} =
             error
  end

  @nodes 3
  cluster "automatically connect", %{nodes: nodes} do
    [node1, node2, node3] = nodes

    # Start MnesiaClusterManager
    opts = [auto_connect: true, master: node1]
    :ok = multi_spawn_request!(nodes, MnesiaClusterManager, opts)

    # All nodes must be connected
    {result, []} = :rpc.multicall(nodes, MnesiaClusterManager, :wait_connected, [@timeout])
    assert [:ok, :ok, :ok] = result

    # And also Mnesia
    {result, []} = :rpc.multicall(nodes, :mnesia, :system_info, [:running_db_nodes])

    Enum.each(result, fn node_result ->
      assert node1 in node_result
      assert node2 in node_result
      assert node3 in node_result
    end)
  end

  @nodes 1
  cluster "trying to connect to invalid node", %{nodes: [node]} do
    # Start MnesiaClusterManager
    :ok = multi_spawn_request!([node], MnesiaClusterManager, retry: 1)
    refute :rpc.call(node, MnesiaClusterManager, :connected?, [])

    # Connect to an invalid node
    assert {:error, :retry_limit_exceed} =
             :rpc.call(node, MnesiaClusterManager, :connect, [invalid_node()])

    refute :rpc.call(node, MnesiaClusterManager, :connected?, [])
  end

  ## Helpers

  defp now(), do: System.monotonic_time(:millisecond)
  defp invalid_node(), do: :"invalid_node@127.0.0.1"

  def retry(fun, timeout, start \\ now()) do
    if now() >= start + timeout do
      {:error, :timeout}
    else
      case fun.() do
        true -> :ok
        false -> retry(fun, timeout, start)
      end
    end
  end

  defp multi_spawn_request!(nodes, module, opts \\ []) do
    Enum.map(nodes, &Node.spawn_link(&1, module, :start_link, [opts]))

    # Here this case is pretty weird:
    # start_link is supposed to be synchronous but the function return before
    # the process being spawned. So I need to wait for local name registration
    case retry(fn -> wait_for_spawn!(nodes, module) end, @timeout) do
      :ok ->
        :ok

      {:error, :timeout} ->
        raise "timeout: #{inspect(module)} not found on all nodes #{inspect(nodes)}"
    end
  end

  defp wait_for_spawn!(nodes, module) do
    {result, []} = :rpc.multicall(nodes, Process, :whereis, [module])
    Enum.all?(result)
  end
end
