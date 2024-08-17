defmodule ElvenGard.Cluster.MnesiaClusterManager do
  @moduledoc """
  TODO: Documentation
  """

  use GenServer

  require Logger

  @type storage_type :: :ram_copies | :disc_copies | :disc_only_copies

  @default_name __MODULE__

  ## Public API

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, @default_name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec connect(node(), timeout()) :: :ok | {:error, :retry_limit_exceed}
  def connect(master, timeout \\ :infinity) do
    GenServer.call(@default_name, {:connect, master}, timeout)
  end

  @spec connected?() :: boolean()
  def connected?() do
    GenServer.call(@default_name, :connected?)
  end

  @spec wait_connected(timeout()) :: :ok | {:error, :timeout}
  def wait_connected(timeout \\ :infinity) do
    do_wait_connected(timeout)
  end

  ## GenServer behaviour

  @impl true
  def init(opts) do
    retry = Keyword.get(opts, :retry, :infinity)
    retry_interval = Keyword.get(opts, :retry_interval, 1000)
    copy_type = Keyword.get(opts, :copy_type, :ram_copies)

    master = Keyword.get(opts, :master)
    auto_connect = Keyword.get(opts, :auto_connect, false)

    state = %{
      retry: retry,
      retry_interval: retry_interval,
      copy_type: copy_type,
      connected: false
    }

    case {auto_connect, master} do
      {true, nil} ->
        raise ArgumentError, ":master node option is required when auto_connect is enabled"

      {true, _} ->
        schedule_connect_node(master, retry, retry_interval)

      _ ->
        :ok
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:connected?, _from, state) do
    {:reply, state.connected, state}
  end

  def handle_call({:connect, master}, from, state) do
    %{retry: retry, retry_interval: retry_interval} = state
    schedule_connect_node(master, retry, retry_interval, from)
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
  def handle_info({:connect, _master, counter, from}, state) when counter < 1 do
    maybe_reply(from, {:error, :retry_limit_exceed})
    {:noreply, state}
  end

  def handle_info({:connect, master, counter, from}, state) do
    %{retry_interval: retry_interval, copy_type: copy_type} = state

    case {try_connect_node(master, copy_type), counter} do
      {{:error, :noconnection}, counter} when counter == :infinity or counter > 1 ->
        Logger.warning(
          "connect cannot connect to #{inspect(master)}, retry in #{retry_interval}ms"
        )

        new_counter = if counter == :infinity, do: :infinity, else: counter - 1
        schedule_connect_node(master, new_counter, retry_interval, from)
        {:noreply, state}

      {{:error, :noconnection}, _counter} ->
        Logger.warning("connect cannot connect to #{inspect(master)}")
        maybe_reply(from, {:error, :retry_limit_exceed})
        {:noreply, state}

      {:ok, _} ->
        Logger.info("connected to master: #{inspect(master)} - copy_type: #{inspect(copy_type)}")
        maybe_reply(from, :ok)
        {:noreply, %{state | connected: true}}
    end
  end

  ## Helpers

  defp now(), do: System.monotonic_time(:millisecond)

  defp maybe_reply(nil, _reply), do: :ok
  defp maybe_reply(from, reply), do: GenServer.reply(from, reply)

  defp expired_timeout?(_start, :infinity), do: false
  defp expired_timeout?(start, timeout), do: now() > start + timeout

  defp schedule_connect_node(master, counter, interval, from \\ nil) do
    if master != node() do
      Process.send_after(self(), {:connect, master, counter, from}, interval)
    end
  end

  defp try_connect_node(master, copy_type) do
    Logger.debug("connect trying to connect to #{inspect(master)}")

    result = GenServer.multi_call([master], @default_name, {:request_join, node(), copy_type})

    case result do
      {[{^master, :ok}], []} -> :ok
      _ -> {:error, :noconnection}
    end
  end

  defp do_wait_connected(start \\ now(), timeout) do
    with {:timeout, false} <- {:timeout, expired_timeout?(start, timeout)},
         {:connected, true} <- {:connected, connected?()} do
      :ok
    else
      {:timeout, true} ->
        {:error, :timeout}

      {:connected, false} ->
        Process.sleep(10)
        do_wait_connected(start, timeout)
    end
  end
end
