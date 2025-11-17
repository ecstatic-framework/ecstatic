defmodule Ecstatic.Entity do
  @moduledoc """
  Entity module for distributed ECS.

  Entities are the basic containers in the ECS pattern. Each entity has:
  - A unique ID (UUID)
  - A collection of components (data)

  ## Usage

  Define your own entity types using the Entity DSL:

      defmodule Player do
        use Ecstatic.Entity

        @default_components [
          Health,
          Position
        ]
      end

  Create entities:

      player = Player.new()
      player = Player.new([Velocity.new(%{dx: 1, dy: 0})])

  ## Distribution

  Entities are automatically distributed across the cluster using Horde.
  You don't need to worry about which node an entity is on - just use its ID.

      # Works regardless of which node the entity is on
      Ecstatic.Entity.add(player, PowerUp.new())
  """

  alias Ecstatic.{
    Component,
    Aspect,
    Changes,
    Distributed.EntityServer,
    Distributed.Supervisor
  }

  defstruct [:id, components: []]

  @type id :: String.t()
  @type uninitialized_component :: atom()
  @type components :: list(Component.t())
  @type t :: %__MODULE__{
          id: String.t(),
          components: components
        }

  # === Macro DSL (keeps existing ECS API) ===

  defmacro __using__(_options) do
    quote location: :keep do
      Module.register_attribute(__MODULE__, :default_components, [])
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote location: :keep do
      @default_components @default_components || []
      def new(components \\ []) do
        # Filter out any components passed in which are duplicates of default components
        passed_comp_modules = Enum.reduce(components, %{}, fn comp, acc ->
          Map.put(acc, comp.type, false)
        end)

        default_comps =
          Enum.filter(@default_components, fn def_comp ->
            Map.get(passed_comp_modules, def_comp, true)
          end)

        Ecstatic.Entity.new(components ++ default_comps)
      end
    end
  end

  # === Public API ===

  @doc """
  Creates a new entity with the given components.

  The entity will be started under Horde supervision and distributed
  automatically across the cluster.

  Returns an entity struct with ID and components.
  """
  @spec new(components) :: t
  def new(components) when is_list(components) do
    entity_id = id()

    # Start entity server under Horde supervision
    child_spec = %{
      id: entity_id,
      start: {EntityServer, :start_link, [{entity_id, components}]},
      restart: :transient
    }

    case Supervisor.start_entity(child_spec) do
      {:ok, _pid} ->
        %__MODULE__{id: entity_id, components: components}

      {:error, {:already_started, _pid}} ->
        %__MODULE__{id: entity_id, components: components}

      {:error, reason} ->
        raise "Failed to create entity: #{inspect(reason)}"
    end
  end

  @doc """
  Get the full current state of an entity from the cluster.

  This fetches the entity from wherever it's running in the cluster.
  """
  @spec get(id) :: {:ok, t} | {:error, :entity_not_found}
  def get(entity_id) when is_binary(entity_id) do
    case EntityServer.get(entity_id) do
      {:ok, entity_data} ->
        {:ok, %__MODULE__{id: entity_data.id, components: entity_data.components}}

      error ->
        error
    end
  end

  @doc """
  Add an initialized component to an entity.

  The component can be:
  - An initialized component struct: `Health.new(%{points: 100})`
  - A component module: `Health` (will be initialized with defaults)
  """
  @spec add(t | id, Component.t() | atom()) :: :ok | {:error, term()}
  def add(%__MODULE__{id: entity_id}, component), do: add(entity_id, component)

  def add(entity_id, component) when is_binary(entity_id) do
    EntityServer.add_component(entity_id, component)
  end

  @doc """
  Update an existing component on an entity.
  """
  @spec update(t | id, Component.t()) :: :ok | {:error, term()}
  def update(%__MODULE__{id: entity_id}, component), do: update(entity_id, component)

  def update(entity_id, component) when is_binary(entity_id) do
    EntityServer.update_component(entity_id, component)
  end

  @doc """
  Remove a component from an entity by type.
  """
  @spec remove(t | id, atom()) :: :ok | {:error, term()}
  def remove(%__MODULE__{id: entity_id}, component_type), do: remove(entity_id, component_type)

  def remove(entity_id, component_type) when is_binary(entity_id) do
    EntityServer.remove_component(entity_id, component_type)
  end

  @doc """
  Get a specific component from an entity.
  """
  @spec get_component(t | id, atom()) :: {:ok, Component.t()} | {:error, :not_found}
  def get_component(%__MODULE__{id: entity_id}, component_type),
    do: get_component(entity_id, component_type)

  def get_component(entity_id, component_type) when is_binary(entity_id) do
    EntityServer.get_component(entity_id, component_type)
  end

  @doc """
  Checks if an entity matches an aspect.

  An aspect defines which components an entity must have (or not have).
  """
  @spec match_aspect?(t, Aspect.t()) :: boolean
  def match_aspect?(entity, aspect) do
    Enum.all?(aspect.with, &has_component?(entity, &1)) &&
      !Enum.any?(aspect.without, &has_component?(entity, &1))
  end

  @doc """
  Check if an entity has an instance of a given component.

  Works with both entity structs and entity IDs.
  For entity IDs, fetches the component from the cluster.
  """
  @spec has_component?(t | id, uninitialized_component) :: boolean
  def has_component?(%__MODULE__{components: components}, component_type) do
    Enum.any?(components, &(&1.type == component_type))
  end

  def has_component?(entity_id, component_type) when is_binary(entity_id) do
    case EntityServer.has_component?(entity_id, component_type) do
      bool when is_boolean(bool) -> bool
      _ -> false
    end
  end

  @doc """
  Find a component in an entity by type.

  For entity structs, searches the local components list.
  For entity IDs, fetches from the cluster.
  """
  @spec find_component(t | id, uninitialized_component) :: Component.t() | nil
  def find_component(%__MODULE__{components: components}, component_type) do
    Enum.find(components, &(&1.type == component_type))
  end

  def find_component(entity_id, component_type) when is_binary(entity_id) do
    case EntityServer.get_component(entity_id, component_type) do
      {:ok, component} -> component
      _ -> nil
    end
  end

  @doc """
  Apply a batch of changes to an entity.

  Changes can include:
  - `:attached` - new components
  - `:updated` - modified components
  - `:removed` - component types to remove
  """
  @spec apply_changes(t | id, Changes.t()) :: :ok | {:error, term()}
  def apply_changes(%__MODULE__{id: entity_id}, changes), do: apply_changes(entity_id, changes)

  def apply_changes(entity_id, changes) when is_binary(entity_id) do
    EntityServer.apply_changes(entity_id, changes)
  end

  # === Private Helpers ===

  defp id, do: Ecstatic.ID.new()
end
