defmodule Ecstatic.System do
  @moduledoc """
  System behavior for distributed ECS.

  Systems contain the logic that operates on entities with specific components.
  They define:
  - An aspect (which components an entity must have)
  - A dispatch function (the logic to run)

  ## Usage

      defmodule MovementSystem do
        use Ecstatic.System

        def aspect do
          %Aspect{with: [Position, Velocity], without: [Frozen]}
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

  ## Distribution

  Systems can run on any node in the cluster. When you call `process/1` or `process/2`,
  the system will fetch the entity from wherever it's located and apply the changes.

  Events are propagated via Phoenix.PubSub, so systems running on different nodes
  can react to the same entity changes.
  """

  alias Ecstatic.{Aspect, Changes, Entity}

  @callback aspect() :: Aspect.t()
  @callback dispatch(entity :: Entity.t(), optional_change) :: Changes.t()

  @type optional_change :: Changes.t() | nil

  @doc false
  defmacro __using__(_options) do
    quote location: :keep do
      @behaviour Ecstatic.System
      alias Ecstatic.{Aspect, Changes, Component, Entity}

      @type dispatch_fun ::
              (Entity.t() -> Changes.t())
              | (Entity.t(), Changes.t() -> Changes.t())
      @type event_push :: :ok

      def process(entity_or_id, changes \\ nil)

      @spec process(entity :: Entity.t() | Entity.id(), nil) :: :ok | {:error, term()}
      def process(entity_or_id, nil) do
        function = fn entity -> dispatch(entity) end
        do_process(entity_or_id, function)
      end

      @spec process(entity :: Entity.t() | Entity.id(), changes :: Changes.t()) :: :ok | {:error, term()}
      def process(entity_or_id, changes) do
        function = fn entity -> dispatch(entity, changes) end
        do_process(entity_or_id, function)
      end

      @spec do_process(Entity.t() | Entity.id(), dispatch_fun()) :: :ok | {:error, term()}
      def do_process(entity_or_id, function) do
        # Fetch entity if we only have an ID
        entity = case entity_or_id do
          %Entity{} = e -> e
          entity_id when is_binary(entity_id) ->
            case Entity.get(entity_id) do
              {:ok, e} -> e
              {:error, _} -> nil
            end
        end

        if entity do
          # Check if entity matches aspect
          if Entity.match_aspect?(entity, aspect()) do
            # Execute the system logic
            changes = function.(entity)

            # Apply changes to the entity (distributed)
            Entity.apply_changes(entity.id, changes)
          else
            # Entity doesn't match aspect, return empty changes
            :ok
          end
        else
          {:error, :entity_not_found}
        end
      end

      @doc """
      Subscribe this system to entity events.

      Call this in your system's init or setup to receive events via PubSub.

      ## Options

      - `:entities` - List of entity IDs to subscribe to
      - `:components` - List of component types to watch
      - `:all` - Subscribe to all entity events (use sparingly!)

      ## Examples

          # Subscribe to specific entities
          MovementSystem.subscribe(entities: ["entity-1", "entity-2"])

          # Subscribe to all Position component changes
          MovementSystem.subscribe(components: [Position])

          # Subscribe to both
          MovementSystem.subscribe(
            entities: ["player-1"],
            components: [Health, Position]
          )
      """
      def subscribe(opts \\ []) do
        # Subscribe to specific entities
        Enum.each(opts[:entities] || [], fn entity_id ->
          Phoenix.PubSub.subscribe(Ecstatic.PubSub, "entity:#{entity_id}")
        end)

        # Subscribe to component types
        Enum.each(opts[:components] || [], fn component_type ->
          Phoenix.PubSub.subscribe(Ecstatic.PubSub, "component:#{component_type}")
        end)

        # Subscribe to all events (if explicitly requested)
        if opts[:all] do
          Phoenix.PubSub.subscribe(Ecstatic.PubSub, "entity:*")
        end

        :ok
      end

      @doc """
      Unsubscribe from entity events.
      """
      def unsubscribe(opts \\ []) do
        Enum.each(opts[:entities] || [], fn entity_id ->
          Phoenix.PubSub.unsubscribe(Ecstatic.PubSub, "entity:#{entity_id}")
        end)

        Enum.each(opts[:components] || [], fn component_type ->
          Phoenix.PubSub.unsubscribe(Ecstatic.PubSub, "component:#{component_type}")
        end)

        if opts[:all] do
          Phoenix.PubSub.unsubscribe(Ecstatic.PubSub, "entity:*")
        end

        :ok
      end
    end
  end
end
