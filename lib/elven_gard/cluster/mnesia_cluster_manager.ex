defmodule ElvenGard.Cluster.MnesiaClusterManager do
  @moduledoc """
  TODO: Documentation
  """

  use GenServer

  require Logger

  @type storage_type :: :ram_copies | :disc_copies | :disc_only_copies

  @default_name __MODULE__
  @default_timeout 5_000

  ## Public API

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, @default_name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec connect_node(timeout()) :: :ok | {:error, :retry_limit_exceed}
  def connect_node(timeout \\ @default_timeout) do
    GenServer.call(@default_name, :connect_node, timeout)
  end

  @spec connected?() :: boolean()
  def connected?() do
    GenServer.call(@default_name, :connected?)
  end

  ## GenServer behaviour

  @impl true
  def init(opts) do
    retry = Keyword.get(opts, :retry, :infinity)
    retry_interval = Keyword.get(opts, :retry_interval, 1000)
    copy_type = Keyword.get(opts, :copy_type, :ram_copies)
    auto_connect = Keyword.get(opts, :auto_connect, true)

    state = %{
      retry: retry,
      retry_interval: retry_interval,
      copy_type: copy_type,
      connected: false
    }

    if auto_connect, do: schedule_connect_node(retry, copy_type)

    {:ok, state}
  end

  @impl true
  def handle_call(:connected?, _from, state) do
    {:reply, state.connected, state}
  end

  def handle_call(:connect_node, from, state) do
    %{retry: retry, copy_type: copy_type} = state
    schedule_connect_node(retry, copy_type, from)
    {:noreply, state}
  end

  def handle_call({:request_join, slave, copy_type}, _from, state) do
    Logger.info("request_join slave: #{inspect(slave)} - copy_type: #{inspect(copy_type)}")

    # Add an extra node to Mnesia
    {:ok, _} = :mnesia.change_config(:extra_db_nodes, [slave])

    # Copy all tables on the slave
    tables = :mnesia.system_info(:tables)
    Enum.map(tables, &:mnesia.add_table_copy(&1, slave, copy_type))

    # Set connected to true
    {:reply, :ok, %{state | connected: true}}
  end

  @impl true
  def handle_info({:connect_node, 0, from}, state) do
    unless is_nil(from), do: GenServer.reply(from, {:error, :retry_limit_exceed})
    {:noreply, state}
  end

  def handle_info({:connect_node, counter, from}, state) do
    %{retry_interval: retry_interval, copy_type: copy_type} = state

    case try_connect_node(Node.list(), copy_type) do
      {:error, :not_found} ->
        Logger.info("connect_node no node found, retry in #{retry_interval}ms")
        schedule_connect_node(counter - 1, retry_interval, from)
        {:noreply, state}

      {:ok, node} ->
        Logger.info("connect_node master: #{inspect(node)} - copy_type: #{inspect(copy_type)}")
        {:noreply, %{state | connected: true}}
    end
  end

  ## Helpers

  defp schedule_connect_node(counter, interval, from \\ nil) do
    Process.send_after(self(), {:connect_node, counter, from}, interval)
  end

  defp try_connect_node([], _copy_type), do: {:error, :not_found}

  defp try_connect_node([master | _nodes], copy_type) do
    GenServer.multi_call([master], __MODULE__, {:request_join, node(), copy_type}) |> IO.inspect()
    {:ok, master}
  end
end
