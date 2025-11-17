defmodule Ecstatic.Application do
  @moduledoc """
  Main application supervisor for distributed Ecstatic ECS.

  Starts:
  - Phoenix.PubSub for distributed event propagation
  - Horde.Registry for entity location
  - Horde.DynamicSupervisor for entity distribution
  """
  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("Starting Ecstatic distributed ECS on node #{node()}")

    children = [
      # PubSub for distributed events
      {Phoenix.PubSub, name: Ecstatic.PubSub},

      # Horde Registry for entity location across cluster
      {Ecstatic.Distributed.Registry, []},

      # Horde DynamicSupervisor for entity distribution
      {Ecstatic.Distributed.Supervisor, []},

      # Optional: Cluster management (if configured)
      {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies, []), [name: Ecstatic.ClusterSupervisor]]}
    ]

    opts = [strategy: :one_for_one, name: Ecstatic.ApplicationSupervisor]
    Supervisor.start_link(children, opts)
  end
end
