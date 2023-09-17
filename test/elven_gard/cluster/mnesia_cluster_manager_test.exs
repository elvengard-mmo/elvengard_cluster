defmodule ElvenGard.Cluster.MnesiaClusterManagerTest do
  use ExUnit.Case, async: true
  use ElvenGard.Cluster.Testing.ExUnitCluster

  alias ElvenGard.Cluster.MnesiaClusterManager

  @timeout 5_000

  ## Setup

  setup %{nodes: nodes} do
    # Remove logs
    :rpc.multicall(nodes, Logger, :configure, [[level: :warn]])
    :ok
  end

  ## Tests

  @nodes 3
  cluster "create cluster and manually connect", %{nodes: nodes} do
    [node1, node2, node3] = nodes

    # Start MnesiaClusterManager
    opts = [auto_connect: false, retry_interval: 10]
    :ok = multi_spawn_request!(nodes, MnesiaClusterManager, opts)

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

    {result, []} = :rpc.multicall(nodes, :mnesia, :system_info, [:running_db_nodes])
    assert [^node2, ^node1] = Enum.at(result, 0)
    assert [^node1, ^node2] = Enum.at(result, 1)
    assert [^node3] = Enum.at(result, 2)

    # Connect node2 to node 1
    {result, []} = :rpc.multicall([node3], MnesiaClusterManager, :connect, [node2])
    assert [:ok] = result

    {result, []} = :rpc.multicall(nodes, :mnesia, :system_info, [:running_db_nodes])
    assert [^node3, ^node2, ^node1] = Enum.at(result, 0)
    assert [^node3, ^node1, ^node2] = Enum.at(result, 1)
    assert [^node1, ^node2, ^node3] = Enum.at(result, 2)
  end

  ## Helpers

  defp now(), do: System.monotonic_time(:millisecond)

  defp multi_spawn_request!(nodes, module, opts) do
    Enum.map(nodes, &Node.spawn_link(&1, module, :start_link, [opts]))

    # Here this case is pretty weird:
    # start_link is supposed to be synchronous but the function return before
    # the process being spawned. So I need to wait for local name registration
    wait_for_spawn!(nodes, module, @timeout)
  end

  defp wait_for_spawn!(nodes, module, timeout, start \\ now()) do
    if now() >= start + timeout do
      raise "timeout: #{inspect(module)} not found on all nodes #{inspect(nodes)}"
    end

    {result, []} = :rpc.multicall(nodes, Process, :whereis, [module])

    case Enum.all?(result) do
      true -> :ok
      false -> wait_for_spawn!(nodes, module, timeout, start)
    end
  end
end
