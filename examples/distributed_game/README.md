# Distributed Game Example

This example demonstrates how to use Ecstatic ECS in a distributed Elixir cluster.

## Features Demonstrated

1. **Entity Distribution**: Entities automatically distributed across nodes
2. **Cross-Node Events**: Systems react to changes regardless of node
3. **Cluster Failover**: Entities automatically restart on other nodes if a node crashes
4. **ECS Patterns**: Components, Systems, Watchers, and Aspects in a game context

## Running the Example

### Start a 3-Node Cluster

In three separate terminals:

**Terminal 1 (Node A)**:
```bash
iex --sname node_a --cookie ecstatic_cluster -S mix
```

**Terminal 2 (Node B)**:
```bash
iex --sname node_b --cookie ecstatic_cluster -S mix
```

**Terminal 3 (Node C)**:
```bash
iex --sname node_c --cookie ecstatic_cluster -S mix
```

### Connect the Nodes

In `node_a`:
```elixir
Node.connect(:"node_b@hostname")
Node.connect(:"node_c@hostname")
```

Or use the helper:
```elixir
DistributedGame.connect_cluster()
```

### Run the Example

```elixir
# In any node:
DistributedGame.run()
```

This will:
1. Create 100 entities distributed across all nodes
2. Simulate combat between entities
3. Show entities dying and respawning
4. Demonstrate cross-node event propagation

### Check Distribution

```elixir
# See which entities are on which node
DistributedGame.show_distribution()

# Count entities
Ecstatic.Distributed.Store.count()

# Query entities
Ecstatic.Distributed.Store.query(with: [Health, Position])
```

### Test Failover

1. Create some entities
2. Note which node they're on
3. Kill that node
4. Watch entities restart on other nodes automatically!

## Components

- **Health**: Entity health points
- **Position**: 2D position
- **Velocity**: 2D movement vector
- **Damage**: Attack damage value
- **Team**: Team affiliation

## Systems

- **MovementSystem**: Moves entities based on velocity
- **CombatSystem**: Handles damage between nearby enemies
- **DeathSystem**: Removes dead entities
- **SpawnSystem**: Creates new entities

## Architecture

```
Node A          Node B          Node C
├─ Player1      ├─ Enemy5       ├─ Enemy8
├─ Enemy1       ├─ Enemy6       ├─ Enemy9
├─ Enemy2       ├─ Enemy7       └─ Enemy10
└─ Enemy3       └─ PowerUp1

All nodes communicate via Phoenix.PubSub
Entities automatically redistribute if a node fails
```
