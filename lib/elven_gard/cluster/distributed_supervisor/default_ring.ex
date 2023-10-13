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
    replicas = Keyword.get(opts, :replicas, default_replicas(nodes))

    %Ring{
      # Sort to ensure all physical nodes will have the same ring
      nodes: Enum.sort(nodes),
      vnode_size: vnode_size,
      replicas: replicas
    }
  end

  @impl true
  def hash(key, _ring) do
    <<value::integer-160>> = :crypto.hash(:sha, :erlang.term_to_binary(key))
    value
  end

  ## Helpers

  defp default_replicas(nodes), do: min(length(nodes), 3)

  defp validate_nodes!(opts) do
    case Keyword.get(opts, :nodes) do
      nodes when is_list(nodes) ->
        nodes

      value ->
        raise ArgumentError, ":nodes is required and must be a list. Got #{inspect(value)}"
    end
  end
end
