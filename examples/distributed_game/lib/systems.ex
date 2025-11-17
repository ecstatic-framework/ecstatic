defmodule DistributedGame.Systems do
  @moduledoc """
  Systems for the distributed game.

  These systems demonstrate:
  - Working with entities across nodes
  - Reactive event-driven logic
  - Cross-component interactions
  """

  alias Ecstatic.{Aspect, Changes, Entity}
  alias DistributedGame.Components.{Health, Position, Velocity, Damage, Team, Name}

  defmodule MovementSystem do
    @moduledoc """
    Moves entities based on their velocity.
    Updates position every tick.
    """
    use Ecstatic.System

    def aspect do
      %Aspect{with: [Position, Velocity], without: []}
    end

    def dispatch(entity) do
      position = Entity.find_component(entity, Position)
      velocity = Entity.find_component(entity, Velocity)

      new_position = Position.new(%{
        x: position.state.x + velocity.state.dx,
        y: position.state.y + velocity.state.dy
      })

      %Changes{updated: [new_position]}
    end
  end

  defmodule CombatSystem do
    @moduledoc """
    Handles combat between entities.

    Entities with Damage component can hurt nearby entities on different teams.
    """
    use Ecstatic.System

    def aspect do
      %Aspect{with: [Health, Position, Team, Damage], without: []}
    end

    def dispatch(entity) do
      # In a real implementation, this would query nearby entities
      # For demo purposes, we'll just reduce health randomly
      health = Entity.find_component(entity, Health)

      if :rand.uniform() < 0.1 do
        damage = :rand.uniform(10)
        new_health = Health.new(%{
          points: max(0, health.state.points - damage),
          max_points: health.state.max_points
        })

        %Changes{updated: [new_health]}
      else
        %Changes{}
      end
    end
  end

  defmodule DeathSystem do
    @moduledoc """
    Handles entity death when health reaches 0.
    """
    use Ecstatic.System
    require Logger

    def aspect do
      %Aspect{with: [Health], without: []}
    end

    def dispatch(entity, changes) do
      health = Entity.find_component(entity, Health)
      name = Entity.find_component(entity, Name)

      if health.state.points <= 0 do
        entity_name = if name, do: name.state.value, else: entity.id
        Logger.info("💀 #{entity_name} has died on node #{node()}")

        # In a real game, you might want to:
        # - Spawn a death animation
        # - Drop loot
        # - Update score
        # - Respawn after delay

        # For now, we'll just mark it (you could also delete the entity)
        %Changes{}
      else
        %Changes{}
      end
    end
  end

  defmodule HealSystem do
    @moduledoc """
    Gradually heals entities over time.
    """
    use Ecstatic.System

    def aspect do
      %Aspect{with: [Health], without: []}
    end

    def dispatch(entity) do
      health = Entity.find_component(entity, Health)

      if health.state.points < health.state.max_points and health.state.points > 0 do
        new_health = Health.new(%{
          points: min(health.state.max_points, health.state.points + 1),
          max_points: health.state.max_points
        })

        %Changes{updated: [new_health]}
      else
        %Changes{}
      end
    end
  end

  defmodule DebugSystem do
    @moduledoc """
    Debug system that logs entity state.
    """
    use Ecstatic.System
    require Logger

    def aspect do
      %Aspect{with: [Health, Position], without: []}
    end

    def dispatch(entity) do
      health = Entity.find_component(entity, Health)
      position = Entity.find_component(entity, Position)
      name = Entity.find_component(entity, Name)

      entity_name = if name, do: name.state.value, else: String.slice(entity.id, 0..7)

      Logger.debug(
        "🎮 #{entity_name} @ (#{Float.round(position.state.x, 1)}, #{Float.round(position.state.y, 1)}) " <>
        "HP: #{health.state.points}/#{health.state.max_points} on #{node()}"
      )

      %Changes{}
    end
  end
end
