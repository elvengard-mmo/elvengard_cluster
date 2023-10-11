defmodule ElvenGard.Cluster.DistributedSupervisor.Ring do
  @moduledoc """
  TODO: Documentation
  """

  alias __MODULE__

  ## Structure

  @enforce_keys [:nodes, :vnode_size, :n]
  defstruct [:nodes, :vnode_size, :n, vnodes: []]

  @type vnode :: {node :: node(), ring_index :: non_neg_integer(), pid :: pid()}

  @type t :: %Ring{
          # All nodes presents on the ring
          nodes: [node()],
          # Total size of the ring
          vnode_size: non_neg_integer(),
          # Number of "replicates" (pref list)
          n: non_neg_integer(),
          # All vnodes presents on the current physical node
          vnodes: [vnode()]
        }

  ## Behaviour

  @doc "Creates a new Ring from args"
  @callback new(opts :: Keyword.t()) :: Ring.t()

  @doc "Returns a hash (used as a vNode index) for a given term"
  @callback hash(key :: any(), ring :: Ring.t()) :: non_neg_integer()

  @doc "Returns the max value for the `hash/2` function"
  @callback max_hash() :: non_neg_integer()
end
