defmodule Ecstatic.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ecstatic,
      version: "0.1.1",
      elixir: "~> 1.8",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      name: "Ecstatic",
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Ecstatic.Application, []}
    ]
  end

  defp package do
    [
      description: "An ECS (Entity-Component-System) framework in Elixir",
      licenses: ["MIT"],
      maintainers: ["Aldric Giacomoni"],
      links: %{github: "https://github.com/trevoke/ecstatic"},
      source_url: "https://github.com/trevoke/ecstatic"
    ]
  end

  defp docs do
    [
      main: "Ecstatic",
      source_url: "https://github.com/trevoke/ecstatic"
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:uuid, "~> 1.1"},
      {:gen_stage, "~> 0.12.2"},
      {:dialyxir, "~> 1.0-pre4", only: [:dev], runtime: false},
      # Distributed ECS infrastructure
      {:horde, "~> 0.8.7"},
      {:phoenix_pubsub, "~> 2.1"},
      {:libcluster, "~> 3.3"},
      {:jason, "~> 1.4"}
    ]
  end
end
