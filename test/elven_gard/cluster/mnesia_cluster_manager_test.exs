defmodule ElvenGard.Cluster.MnesiaClusterManagerTest do
  use ExUnit.Case, async: true

  alias ElvenGard.Cluster.MnesiaClusterManager
  alias ElvenGard.Cluster.Testing.LocalCluster

  ## Tests

  test "toto" do
    # Start nodes
    [node1, node2] = nodes = start_nodes("my-cluster", 2)

    # Start MnesiaClusterManager
    opts = [auto_connect: false, retry_interval: 1]
    :ok = multi_spawn_request(nodes, MnesiaClusterManager, opts)

    :rpc.multicall(nodes, MnesiaClusterManager, :connected?, []) |> IO.inspect()
  end

  ## Helpers

  defp start_nodes(prefix, count) do
    peer_nodes = LocalCluster.start_nodes(prefix, count)
    Enum.map(peer_nodes, &elem(&1, 1))
  end

  defp multi_spawn_request(nodes, module, opts) do
    Enum.map(nodes, &Node.spawn_link(&1, module, :start_link, [opts]))

    # Here this case is pretty weird:
    # start_link is supposed to be synchronous but the function return before
    # the process being spawned. So I need to wait for local name registration
    wait_for_spawn(nodes, module)
  end

  defp wait_for_spawn(nodes, module) do
    {result, []} = :rpc.multicall(nodes, Process, :whereis, [module])

    case Enum.all?(result) do
      true -> :ok
      false -> wait_for_spawn(nodes, module)
    end
  end
end
