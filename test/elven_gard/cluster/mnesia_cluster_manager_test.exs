defmodule ElvenGard.Cluster.MnesiaClusterManagerTest do
  use ExUnit.Case, async: true
  use ElvenGard.Cluster.Testing.ExUnitCluster

  alias ElvenGard.Cluster.MnesiaClusterManager

  @timeout 5_000

  ## Tests

  @nodes 3
  cluster "toto", %{nodes: nodes} do
    # Start MnesiaClusterManager
    opts = [auto_connect: false, retry_interval: 1]
    :ok = multi_spawn_request!(nodes, MnesiaClusterManager, opts)

    :rpc.multicall(nodes, MnesiaClusterManager, :connected?, []) |> IO.inspect()
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
