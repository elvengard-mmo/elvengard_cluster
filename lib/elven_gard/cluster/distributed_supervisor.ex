defmodule ElvenGard.Cluster.DistributedSupervisor do
  @moduledoc """
  TODO: Documentation
  """

  use Supervisor

  alias ElvenGard.Cluster.DistributedSupervisor.Ring

  ## Public API

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  ## Supervisor behaviour

  @impl true
  def init(opts) do
    ring_mod = Keyword.get(opts, :ring, __MODULE__.DefaultRing)
    ring = ring_mod.new(opts)

    children = [
      {DynamicSupervisor, name: vnode_sup(), strategy: :one_for_one},
      {Registry, keys: :unique, name: registry()},
      # __MODULE__.NodeWatcher,
      {Task, fn -> start_vnodes(ring) end}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  ## Internal API

  @doc false
  def registry(), do: __MODULE__.Registry

  ## Helpers

  defp vnode_sup(), do: __MODULE__.VNodeSupervisor

  defp start_vnodes(ring) do
    ring
    # Start the vNode process only if it's on our physical node
    |> Ring.vnodes(:self)
    |> Enum.each(fn {_node, index} ->
      child = {__MODULE__.VNode, index}
      {:ok, _pid} = DynamicSupervisor.start_child(vnode_sup(), child)
    end)
  end
end
