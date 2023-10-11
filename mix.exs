defmodule ElvenGard.Cluster.MixProject do
  use Mix.Project

  @app_name "ElvenGard.Cluster"
  @version "0.1.0"
  # @github_link "https://github.com/ImNotAVirus/elvengard_cluster"

  def project do
    [
      app: :elvengard_cluster,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      name: @app_name,
      description: "Game server toolkit written in Elixir # Clustering",
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    []
  end
end
