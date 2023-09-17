defmodule ElvenGard.Cluster.Testing.ExUnitCluster do
  @moduledoc """
  TODO: Documentation for ElvenGard.Cluster.Testing.ExUnitCluster
  """

  alias ElvenGard.Cluster.Testing.LocalCluster

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: [cluster: 2, cluster: 3]

      ExUnit.Case.register_attribute(__MODULE__, :nodes)

      setup context do
        get_in(context, [:registered, :nodes])
        |> unquote(__MODULE__).validate_nodes!()
        |> unquote(__MODULE__).start_nodes()
      end
    end
  end

  defmacro cluster(message, context \\ quote(do: _), contents) do
    context = Macro.escape(context)
    contents = Macro.escape(contents)

    quote bind_quoted: [context: context, contents: contents, message: message] do
      name = ExUnit.Case.register_test(__ENV__, :cluster, message, [:cluster])

      def unquote(name)(unquote(context)), do: unquote(contents)
    end
  end

  ## Internal functions

  @doc false
  def validate_nodes!(nil), do: 1
  def validate_nodes!(nodes) when is_integer(nodes), do: nodes

  def validate_nodes!(nodes) do
    raise ArgumentError, "@nodes must be an integer, got: #{inspect(nodes)}"
  end

  @doc false
  def start_nodes(count) do
    cluster_name = List.to_string(:peer.random_name())
    peers = LocalCluster.start_nodes(cluster_name, count)
    %{peers: peers, nodes: Enum.map(peers, &elem(&1, 1))}
  end
end
