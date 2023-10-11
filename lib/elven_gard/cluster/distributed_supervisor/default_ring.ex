defmodule ElvenGard.Cluster.DistributedSupervisor.DefaultRing do
  @moduledoc """
  TODO: Documentation
  """

  @behaviour ElvenGard.Cluster.DistributedSupervisor.Ring

  alias ElvenGard.Cluster.DistributedSupervisor.Ring

  ## Ring Behaviour

  @impl true
  def new(opts) do
    nodes = validate_nodes!(opts)
    vnode_size = Keyword.get(opts, :vnode_size, 128)
    n = Keyword.get(opts, :n, length(nodes))

    %Ring{
      # Sort to ensure all physical nodes will have the same list
      nodes: Enum.sort(nodes),
      vnode_size: vnode_size,
      n: n
    }
  end

  @impl true
  def hash(key, %Ring{vnode_size: vnode_size}) do
    key
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha, &1))
    |> rem(vnode_size)
  end

  @impl true
  def max_hash() do
    Integer.pow(2, 160)
  end

  ## Helpers

  defp validate_nodes!(opts) do
    case Keyword.get(opts, :nodes) do
      nodes when is_list(nodes) ->
        nodes

      value ->
        raise ArgumentError, ":nodes is required and must be a list. Got #{inspect(value)}"
    end
  end
end
