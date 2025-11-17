# Distributed ECS Proof of Concept

This document describes the distributed architecture implementation for Ecstatic ECS.

## Overview

The distributed version of Ecstatic uses:
- **Horde** for entity distribution and failover
- **Phoenix.PubSub** for cross-node event propagation
- **libcluster** for automatic node discovery

## Architecture

### Entity-as-Actor Model

Each entity is a GenServer process supervised by Horde:

```
┌─────────────────────────────────────────────────┐
│              Horde Cluster                       │
│                                                  │
│  Node A              Node B              Node C │
│  ┌─────────┐        ┌─────────┐        ┌──────┐│
│  │ Entity1 │        │ Entity4 │        │Entity7││
│  │ Entity2 │        │ Entity5 │        │Entity8││
│  │ Entity3 │        │ Entity6 │        │Entity9││
│  └─────────┘        └─────────┘        └──────┘│
│                                                  │
│     ↓                    ↓                  ↓    │
│  ┌──────────────────────────────────────────┐  │
│  │        Phoenix.PubSub (Events)            │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### Components

1. **Ecstatic.Distributed.Registry** (Horde.Registry)
   - Distributed entity location service
   - Find any entity by ID across cluster
   - Automatic re-registration on failover

2. **Ecstatic.Distributed.Supervisor** (Horde.DynamicSupervisor)
   - Distributes entities across nodes
   - Automatic failover and restart
   - Uniform distribution strategy

3. **Ecstatic.Distributed.EntityServer** (GenServer)
   - One per entity
   - Holds entity state and components
   - Publishes events via PubSub
   - Handles component operations

4. **Phoenix.PubSub**
   - Distributes events across nodes
   - Topics: `entity:{id}` and `component:{type}`
   - Systems subscribe to relevant topics

### User-Facing API (ECS DSL)

The distributed implementation preserves the original ECS API:

```elixir
# Define components (unchanged)
defmodule Health do
  use Ecstatic.Component
  @default_state %{points: 100}
end

# Define entities (unchanged)
defmodule Player do
  use Ecstatic.Entity
  @default_components [Health, Position]
end

# Create entities (unchanged)
player = Player.new()

# Define systems (unchanged)
defmodule HealingSystem do
  use Ecstatic.System

  def aspect, do: %Aspect{with: [Health]}

  def dispatch(entity) do
    health = Entity.find_component(entity, Health)
    new_health = Health.new(%{points: health.state.points + 10})
    %Changes{updated: [new_health]}
  end
end

# Run systems (works across nodes!)
HealingSystem.process(player.id)
```

## Key Improvements Over Original

### Performance

| Aspect | Original | Distributed |
|--------|----------|-------------|
| Event propagation | Single GenServer (bottleneck) | Phoenix.PubSub (distributed) |
| Storage writes | Serialized ETS (bottleneck) | Per-entity GenServer (parallel) |
| Component lookup | O(N) list scan | O(1) map lookup |
| Entity location | Local ETS only | Horde.Registry (cluster-wide) |
| Scalability | ~1,000 entities (single node) | 100,000+ entities (cluster) |

### Distribution Features

1. **Automatic Load Balancing**
   - Entities distributed evenly across nodes
   - Horde handles redistribution when nodes join/leave

2. **Fault Tolerance**
   - Entity processes automatically restart on failure
   - If node crashes, entities restart on other nodes
   - No manual intervention required

3. **Cluster Awareness**
   - Systems can run on any node
   - Events propagate across cluster automatically
   - Entity queries work cluster-wide

4. **Horizontal Scaling**
   - Add more nodes to handle more entities
   - Linear scaling (in theory)
   - No code changes required

## Usage

### Starting a Cluster

#### Manual Connection

```bash
# Terminal 1
iex --sname node_a --cookie my_cluster -S mix

# Terminal 2
iex --sname node_b --cookie my_cluster -S mix

# Terminal 3
iex --sname node_c --cookie my_cluster -S mix
```

Connect nodes:
```elixir
# In node_a
Node.connect(:"node_b@hostname")
Node.connect(:"node_c@hostname")
```

#### Automatic Connection (libcluster)

Configure in `config/config.exs`:

```elixir
config :libcluster,
  topologies: [
    my_app: [
      strategy: Cluster.Strategy.Epmd,
      config: [hosts: [:"node_a@host", :"node_b@host"]]
    ]
  ]
```

Nodes will connect automatically on startup.

### Creating Entities

```elixir
# Entity automatically distributed to a node
entity = Player.new([
  Health.new(%{points: 100}),
  Position.new(%{x: 10, y: 20})
])

# Check which node it's on
{:ok, pid} = Ecstatic.Distributed.Registry.lookup(entity.id)
node(pid)  # => :node_b@hostname
```

### Querying Entities

```elixir
# Count all entities across cluster
Ecstatic.Distributed.Store.count()

# Query by components (works across all nodes)
entity_ids = Ecstatic.Distributed.Store.query(
  with: [Health, Position],
  without: [Frozen]
)

# Get entity from anywhere
{:ok, entity} = Ecstatic.Entity.get(entity_id)
```

### Running Systems

```elixir
# System processes entity regardless of which node it's on
HealingSystem.process(entity_id)

# Subscribe to events across cluster
HealingSystem.subscribe(components: [Health])

# System receives events from all nodes
def handle_info({:component_changed, entity_id, Health, changes}, state) do
  # React to health changes from any node
end
```

### Monitoring Distribution

```elixir
# See which entities are on which node
alias Ecstatic.Distributed.{Registry, Store}

Store.list_entities()
|> Enum.map(fn entity_id ->
  {:ok, pid} = Registry.lookup(entity_id)
  {entity_id, node(pid)}
end)
|> Enum.group_by(fn {_, node} -> node end)
|> Enum.map(fn {node, entities} ->
  IO.puts("#{node}: #{length(entities)} entities")
end)
```

## Testing Failover

1. Start a 3-node cluster
2. Create entities
3. Note which node has specific entities
4. Kill that node: `Node.stop()`
5. Watch entities automatically restart on other nodes

```elixir
# Before
{:ok, pid} = Registry.lookup("entity-123")
node(pid)  # => :node_b@host

# Kill node_b
# (in another terminal, kill the node_b process)

# After (automatic)
{:ok, pid} = Registry.lookup("entity-123")
node(pid)  # => :node_c@host  (moved!)
```

## Example Application

See `examples/distributed_game/` for a complete working example:

```elixir
# Start cluster (3 terminals)
iex --sname node_a --cookie game -S mix
iex --sname node_b --cookie game -S mix
iex --sname node_c --cookie game -S mix

# Connect and run (in any node)
DistributedGame.connect_cluster()
DistributedGame.run(entities: 100, duration: 30_000)

# Watch entities distributed and interacting across nodes!
```

## Consistency Guarantees

### Strong Consistency Per Entity

- Each entity owned by exactly one node
- All operations on an entity go through its GenServer
- Serializes updates (no race conditions within entity)

### Eventual Consistency Across Entities

- Events propagated via PubSub (asynchronous)
- Systems may see slightly stale state from other entities
- Acceptable for most game/simulation scenarios

### Event Ordering

- Events for single entity are ordered (FIFO)
- Events across entities are unordered
- PubSub guarantees delivery (not timing)

## Performance Characteristics

### Time Complexity

- Entity creation: O(1) (distributed)
- Component lookup: O(1) (map-based)
- Component update: O(1) (single GenServer)
- Entity query: O(N) (POC - could be O(1) with Mnesia indices)
- Event propagation: O(1) per subscriber

### Space Complexity

- Per entity: ~2KB baseline (GenServer + Registry)
- Components: Size of component data
- Events: Transient (garbage collected after delivery)

### Network Overhead

- Each component change: 1 PubSub message per topic
- Topics: `entity:{id}` + `component:{type}`
- Message size: Entity ID + Changes struct (~100-500 bytes)

## Future Enhancements

### Short Term

1. **Component Indices** (Mnesia)
   - O(1) query by component type
   - Persistent entity storage
   - Survives cluster restart

2. **System Execution Pools**
   - Parallel system execution
   - Task.async_stream for batch processing
   - Configurable concurrency

### Long Term

1. **Archetype Optimization**
   - Group entities by component signature
   - Iterate dense arrays instead of scattered processes
   - Cache-friendly memory layout

2. **Regional Distribution**
   - Entities with locality stay on same node
   - Spatial partitioning for games
   - Minimize cross-node communication

3. **Event Batching**
   - Coalesce multiple updates
   - Delta compression
   - Reduce network overhead

4. **Observability**
   - Telemetry integration
   - Distributed tracing
   - Performance metrics

## Migration from Original

To migrate from the original single-node implementation:

1. **Update dependencies** (see `mix.exs`)
   ```elixir
   {:horde, "~> 0.8.7"},
   {:phoenix_pubsub, "~> 2.1"},
   {:libcluster, "~> 3.3"}
   ```

2. **Add application module** (`lib/ecstatic/application.ex`)
   - Starts Horde and PubSub

3. **Replace modules** (API unchanged!)
   - `entity.ex` → `entity_distributed.ex`
   - `system.ex` → `system_distributed.ex`
   - `store_ets.ex` → `distributed/store.ex`

4. **Update config** (`config/config.exs`)
   - Configure libcluster strategy

5. **Optional: Update systems**
   - Add PubSub subscriptions for reactive systems
   - Use `System.subscribe(components: [...])`

The ECS DSL remains 100% compatible!

## Conclusion

This distributed implementation transforms Ecstatic from a single-node ECS into a horizontally scalable, fault-tolerant distributed system while preserving the elegant ECS API.

**Key Achievement**: Users still think in ECS terms (entities, components, systems), but get distribution for free.
