defmodule ElvenGard.Cluster.MnesiaClusterManagerTest do
  use ExUnit.Case, async: true

  alias ElvenGard.Cluster.Testing.LocalCluster

  test "toto" do
    peer_nodes = LocalCluster.start_nodes("my-cluster", 3)

    [node1, node2, node3] = Enum.map(peer_nodes, &elem(&1, 1))

    assert Node.ping(node1) == :pong
    assert Node.ping(node2) == :pong
    assert Node.ping(node3) == :pong

    LocalCluster.stop_nodes(peer_nodes)

    assert Node.ping(node1) == :pang
    assert Node.ping(node2) == :pang
    assert Node.ping(node3) == :pang
  end
end
