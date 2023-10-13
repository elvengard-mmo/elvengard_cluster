defmodule ElvenGard.Cluster.DistributedSupervisor.RingTest do
  use ExUnit.Case, async: true

  alias ElvenGard.Cluster.DistributedSupervisor.Ring

  ## Tests

  describe "vnodes/1" do
    test "default value is :self" do
      ring = ring([node(), :"other1@127.0.0.1", :"other2@127.0.0.1"])
      assert Ring.vnodes(ring) == Ring.vnodes(ring, :self)
    end
  end

  describe "vnodes/2" do
    test "with :self option" do
      self = node()
      ring = ring([self, :"other1@127.0.0.1", :"other2@127.0.0.1"])

      assert [{^self, 0}, {^self, 3}] = Ring.vnodes(ring, :self)
    end

    test "with :others option" do
      ring = ring([node(), :"other1@127.0.0.1", :"other2@127.0.0.1"])

      assert [
               "other1@127.0.0.1": 1,
               "other2@127.0.0.1": 2,
               "other1@127.0.0.1": 4
             ] = Ring.vnodes(ring, :others)
    end

    test "with :all option" do
      self = node()
      ring = ring([self, :"other1@127.0.0.1", :"other2@127.0.0.1"])

      assert [
               {^self, 0},
               {:"other1@127.0.0.1", 1},
               {:"other2@127.0.0.1", 2},
               {^self, 3},
               {:"other1@127.0.0.1", 4}
             ] = Ring.vnodes(ring, :all)
    end
  end

  ## Helpers

  defp ring(nodes) do
    %Ring{nodes: nodes, vnode_size: 5, replicas: 3}
  end
end
