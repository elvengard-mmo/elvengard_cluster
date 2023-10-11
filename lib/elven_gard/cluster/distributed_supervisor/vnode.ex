defmodule ElvenGard.Cluster.DistributedSupervisor.VNode do
  @moduledoc """
  TODO: Documentation
  """

  use GenServer

  require Logger

  ## Public API

  def start_link(vindex) do
    GenServer.start_link(__MODULE__, vindex)
  end

  ## Behaviour

  @impl true
  def init(vindex) do
    Logger.debug("Starting vNode##{inspect(vindex)} on #{inspect(node())}")
    {:ok, nil}
  end
end
