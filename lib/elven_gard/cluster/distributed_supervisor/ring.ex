defmodule ElvenGard.Cluster.DistributedSupervisor.Ring do
  @moduledoc """
  TODO: Documentation
  """

  alias __MODULE__

  ## Structure

  @enforce_keys [:nodes, :vnode_size, :replicas]
  defstruct [:nodes, :vnode_size, :replicas]

  @type t :: %Ring{
          # All nodes presents on the ring
          nodes: [node()],
          # Total size of the ring
          vnode_size: non_neg_integer(),
          # Number of "replicates" (pref list)
          replicas: non_neg_integer()
        }

  @type vnode_id :: non_neg_integer()
  @type vnode :: {node(), vnode_id()}

  ## Behaviour

  @doc "Creates a new Ring from args"
  @callback new(opts :: Keyword.t()) :: Ring.t()

  @doc "Hash a term and returns a positive integer"
  @callback hash(key :: any(), ring :: Ring.t()) :: non_neg_integer()

  ## Public API

  @spec vnodes(Ring.t(), :all | :self) :: [vnode()]
  def vnodes(ring, scope \\ :self)

  def vnodes(ring, :self) do
    self = node()
    Enum.filter(vnodes(ring, :all), &match?({^self, _}, &1))
  end

  def vnodes(ring, :others) do
    self = node()
    Enum.reject(vnodes(ring, :all), &match?({^self, _}, &1))
  end

  def vnodes(%Ring{nodes: nodes, vnode_size: vnode_size}, :all) do
    Enum.zip(Stream.cycle(nodes), 0..(vnode_size - 1))
  end
end
