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
      # __MODULE__.NodeWatcher,
      {Task, fn -> start_vnodes(ring) end}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  ## Helpers

  defp vnode_sup(), do: __MODULE__.VNodeSupervisor

  defp start_vnodes(%Ring{nodes: nodes, vnode_size: vnode_size}) do
    self_node = node()

    0..(vnode_size - 1)
    |> Enum.zip(Stream.cycle(nodes))
    |> Enum.each(fn
      # Start the vNode process only if it's on our physical node
      {index, ^self_node} ->
        child = {__MODULE__.VNode, index}
        {:ok, _pid} = DynamicSupervisor.start_child(vnode_sup(), child)

      _ ->
        :ignore
    end)
  end
end
