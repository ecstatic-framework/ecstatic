defmodule DistributedGame do
  @moduledoc """
  Distributed game example using Ecstatic ECS.

  This demonstrates a multi-node game where entities are distributed across
  a cluster and systems react to changes across nodes.
  """

  require Logger
  alias DistributedGame.{Entities, Systems}
  alias Ecstatic.Distributed.Store

  @doc """
  Run the distributed game demo.

  Creates entities, runs systems periodically, and shows distribution.
  """
  def run(opts \\ []) do
    num_entities = opts[:entities] || 10
    duration = opts[:duration] || 30_000

    Logger.info("🎮 Starting Distributed Game on #{node()}")
    Logger.info("📊 Creating #{num_entities} entities...")

    # Create entities
    entities = create_entities(num_entities)

    Logger.info("✅ Created #{length(entities)} entities")
    Logger.info("🌍 Distribution:")
    show_distribution()

    # Run simulation
    Logger.info("🎬 Running simulation for #{duration}ms...")
    run_simulation(duration)

    Logger.info("🏁 Simulation complete!")
    show_stats()
  end

  @doc """
  Create a mix of player and enemy entities.
  """
  def create_entities(count) do
    # Create 1 player and rest enemies
    player = Entities.create_player("Player-#{node()}", x: 50.0, y: 50.0)

    enemies = for i <- 1..count do
      Entities.create_enemy("Enemy-#{i}")
    end

    [player | enemies]
  end

  @doc """
  Run the game simulation for a duration.
  """
  def run_simulation(duration) do
    start_time = System.monotonic_time(:millisecond)

    # Run update loop
    Stream.interval(1000)
    |> Stream.take_while(fn _ ->
      elapsed = System.monotonic_time(:millisecond) - start_time
      elapsed < duration
    end)
    |> Stream.each(fn tick ->
      Logger.info("⏱️  Tick #{tick}")
      run_tick()
    end)
    |> Stream.run()
  end

  @doc """
  Run one game tick.
  """
  def run_tick do
    # Get all entities with Position and Velocity
    entity_ids = Store.query(with: [DistributedGame.Components.Position])

    # Run systems on all entities in parallel
    entity_ids
    |> Task.async_stream(
      fn entity_id ->
        # Run movement
        Systems.MovementSystem.process(entity_id)

        # Run combat
        Systems.CombatSystem.process(entity_id)

        # Run healing
        Systems.HealSystem.process(entity_id)
      end,
      max_concurrency: 50,
      timeout: 5000,
      on_timeout: :kill_task
    )
    |> Stream.run()
  end

  @doc """
  Show how entities are distributed across nodes.
  """
  def show_distribution do
    entity_ids = Store.list_entities()

    distribution =
      entity_ids
      |> Task.async_stream(
        fn entity_id ->
          case Ecstatic.Distributed.Registry.lookup(entity_id) do
            {:ok, pid} -> {entity_id, node(pid)}
            _ -> {entity_id, :unknown}
          end
        end,
        max_concurrency: 100
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> Enum.group_by(fn {_id, node} -> node end)

    Enum.each(distribution, fn {node, entities} ->
      Logger.info("  #{node}: #{length(entities)} entities")
    end)

    distribution
  end

  @doc """
  Show statistics about the game state.
  """
  def show_stats do
    total = Store.count()
    alive = Store.query(with: [DistributedGame.Components.Health]) |> length()

    Logger.info("📊 Statistics:")
    Logger.info("  Total entities: #{total}")
    Logger.info("  Alive entities: #{alive}")
    Logger.info("  Dead entities: #{total - alive}")
  end

  @doc """
  Helper to connect to other nodes in the cluster.

  Usage:
    DistributedGame.connect_cluster([:node_b@hostname, :node_c@hostname])
  """
  def connect_cluster(nodes \\ []) do
    nodes = if nodes == [], do: discover_nodes(), else: nodes

    Enum.each(nodes, fn node ->
      case Node.connect(node) do
        true -> Logger.info("✅ Connected to #{node}")
        false -> Logger.warn("❌ Failed to connect to #{node}")
        :ignored -> Logger.info("Already connected to #{node}")
      end
    end)

    Logger.info("🌐 Cluster: #{inspect([node() | Node.list()])}")
  end

  defp discover_nodes do
    # Try to discover common node names
    hostname = :inet.gethostname() |> elem(1) |> to_string()

    [:node_a, :node_b, :node_c]
    |> Enum.map(fn name -> :"#{name}@#{hostname}" end)
    |> Enum.reject(&(&1 == node()))
  end

  @doc """
  Create a watcher configuration for the distributed game.
  """
  def watchers do
    # This would be configured in config/config.exs
    # For now, return empty list (watchers are optional)
    []
  end
end
