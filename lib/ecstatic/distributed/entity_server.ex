defmodule Ecstatic.Distributed.EntityServer do
  @moduledoc """
  GenServer that represents a single entity in the distributed ECS.

  This is an internal implementation detail - users interact with the
  Ecstatic.Entity module which delegates to this server.

  Each entity:
  - Lives on one node (owner)
  - Is registered in Horde.Registry by entity ID
  - Publishes changes via Phoenix.PubSub
  - Handles failover automatically via Horde
  """
  use GenServer
  require Logger

  alias Ecstatic.{Component, Changes}

  @type entity_id :: String.t()
  @type component_map :: %{atom() => Component.t()}

  defstruct [
    :entity_id,
    :components,
    :watchers
  ]

  # === Public API (called by Ecstatic.Entity) ===

  @doc """
  Start an entity server under Horde supervision.
  """
  def start_link({entity_id, components}) when is_list(components) do
    GenServer.start_link(__MODULE__, {entity_id, components})
  end

  @doc """
  Get the full entity state.
  """
  def get(entity_id) do
    with_entity(entity_id, fn pid ->
      GenServer.call(pid, :get_entity)
    end)
  end

  @doc """
  Add or attach a component to an entity.
  """
  def add_component(entity_id, component) do
    with_entity(entity_id, fn pid ->
      GenServer.call(pid, {:add_component, component})
    end)
  end

  @doc """
  Update an existing component.
  """
  def update_component(entity_id, component) do
    with_entity(entity_id, fn pid ->
      GenServer.call(pid, {:update_component, component})
    end)
  end

  @doc """
  Remove a component by type.
  """
  def remove_component(entity_id, component_type) do
    with_entity(entity_id, fn pid ->
      GenServer.call(pid, {:remove_component, component_type})
    end)
  end

  @doc """
  Get a specific component by type.
  """
  def get_component(entity_id, component_type) do
    with_entity(entity_id, fn pid ->
      GenServer.call(pid, {:get_component, component_type})
    end)
  end

  @doc """
  Check if entity has a component type.
  """
  def has_component?(entity_id, component_type) do
    with_entity(entity_id, fn pid ->
      GenServer.call(pid, {:has_component?, component_type})
    end)
  end

  @doc """
  Apply a batch of changes to an entity.
  """
  def apply_changes(entity_id, changes) do
    with_entity(entity_id, fn pid ->
      GenServer.call(pid, {:apply_changes, changes})
    end)
  end

  # === GenServer Callbacks ===

  @impl true
  def init({entity_id, components}) do
    # Register in distributed registry
    case Ecstatic.Distributed.Registry.register(entity_id, %{
      node: node(),
      started_at: System.system_time(:millisecond)
    }) do
      {:ok, _} ->
        # Convert component list to map for O(1) lookup
        component_map = build_component_map(components)

        # Load watchers from config
        watchers = case Application.get_env(:ecstatic, :watchers) do
          fun when is_function(fun) -> fun.()
          _ -> []
        end

        state = %__MODULE__{
          entity_id: entity_id,
          components: component_map,
          watchers: watchers
        }

        Logger.debug("Entity #{entity_id} started on node #{node()}")

        # Publish entity creation event
        publish_event(entity_id, %Changes{attached: Map.values(component_map)})

        {:ok, state}

      {:error, {:already_registered, _pid}} ->
        {:stop, :already_exists}
    end
  end

  @impl true
  def handle_call(:get_entity, _from, state) do
    entity = %{
      id: state.entity_id,
      components: Map.values(state.components)
    }
    {:reply, {:ok, entity}, state}
  end

  @impl true
  def handle_call({:add_component, component}, _from, state) do
    component = ensure_component_initialized(component)

    if Map.has_key?(state.components, component.type) do
      {:reply, {:error, :already_exists}, state}
    else
      new_components = Map.put(state.components, component.type, component)
      new_state = %{state | components: new_components}

      # Publish change event
      changes = %Changes{attached: [component]}
      publish_event(state.entity_id, changes)

      # Trigger watchers
      trigger_watchers(new_state, :attached, nil, component)

      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:update_component, component}, _from, state) do
    component = ensure_component_initialized(component)
    old_component = Map.get(state.components, component.type)

    if old_component do
      new_components = Map.put(state.components, component.type, component)
      new_state = %{state | components: new_components}

      # Publish change event
      changes = %Changes{updated: [component]}
      publish_event(state.entity_id, changes)

      # Trigger watchers
      trigger_watchers(new_state, :updated, old_component, component)

      {:reply, :ok, new_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:remove_component, component_type}, _from, state) do
    case Map.pop(state.components, component_type) do
      {nil, _} ->
        {:reply, {:error, :not_found}, state}

      {removed_component, new_components} ->
        new_state = %{state | components: new_components}

        # Publish change event
        changes = %Changes{removed: [component_type]}
        publish_event(state.entity_id, changes)

        # Trigger watchers
        trigger_watchers(new_state, :removed, removed_component, nil)

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:get_component, component_type}, _from, state) do
    result = case Map.get(state.components, component_type) do
      nil -> {:error, :not_found}
      component -> {:ok, component}
    end
    {:reply, result, state}
  end

  @impl true
  def handle_call({:has_component?, component_type}, _from, state) do
    {:reply, Map.has_key?(state.components, component_type), state}
  end

  @impl true
  def handle_call({:apply_changes, changes}, _from, state) do
    # Process attached components
    new_components = Enum.reduce(changes.attached || [], state.components, fn comp, acc ->
      component = ensure_component_initialized(comp)
      Map.put(acc, component.type, component)
    end)

    # Process updated components
    new_components = Enum.reduce(changes.updated || [], new_components, fn comp, acc ->
      component = ensure_component_initialized(comp)
      Map.put(acc, component.type, component)
    end)

    # Process removed components
    new_components = Enum.reduce(changes.removed || [], new_components, fn type, acc ->
      Map.delete(acc, type)
    end)

    new_state = %{state | components: new_components}

    # Publish change event
    publish_event(state.entity_id, changes)

    # Trigger watchers for each change type
    Enum.each(changes.attached || [], fn comp ->
      component = ensure_component_initialized(comp)
      trigger_watchers(new_state, :attached, nil, component)
    end)

    Enum.each(changes.updated || [], fn comp ->
      component = ensure_component_initialized(comp)
      old = Map.get(state.components, component.type)
      trigger_watchers(new_state, :updated, old, component)
    end)

    Enum.each(changes.removed || [], fn type ->
      old = Map.get(state.components, type)
      trigger_watchers(new_state, :removed, old, nil)
    end)

    {:reply, :ok, new_state}
  end

  # === Private Helpers ===

  defp with_entity(entity_id, fun) do
    case Ecstatic.Distributed.Registry.lookup(entity_id) do
      {:ok, pid} -> fun.(pid)
      {:error, :not_found} -> {:error, :entity_not_found}
    end
  end

  defp build_component_map(components) do
    components
    |> Enum.map(&ensure_component_initialized/1)
    |> Map.new(fn component -> {component.type, component} end)
  end

  defp ensure_component_initialized(%Component{} = component), do: component
  defp ensure_component_initialized(component_module) when is_atom(component_module) do
    component_module.new()
  end

  defp publish_event(entity_id, changes) do
    # Publish to entity-specific topic
    Phoenix.PubSub.broadcast(
      Ecstatic.PubSub,
      "entity:#{entity_id}",
      {:entity_changed, entity_id, changes}
    )

    # Publish to component-type topics for each changed component
    all_components =
      (changes.attached || []) ++
      (changes.updated || []) ++
      (changes.removed || [])

    all_components
    |> Enum.map(fn
      %Component{type: type} -> type
      type when is_atom(type) -> type
    end)
    |> Enum.uniq()
    |> Enum.each(fn component_type ->
      Phoenix.PubSub.broadcast(
        Ecstatic.PubSub,
        "component:#{component_type}",
        {:component_changed, entity_id, component_type, changes}
      )
    end)
  end

  defp trigger_watchers(state, lifecycle_hook, old_component, new_component) do
    entity = %{id: state.entity_id, components: Map.values(state.components)}
    component_type = case {old_component, new_component} do
      {nil, %Component{type: type}} -> type
      {%Component{type: type}, _} -> type
      _ -> nil
    end

    if component_type do
      state.watchers
      |> Enum.filter(&(&1.component == component_type))
      |> Enum.filter(&(&1.component_lifecycle_hook == lifecycle_hook))
      |> Enum.each(fn watcher ->
        should_run = case Map.get(watcher, :callback) do
          nil -> true
          callback -> callback.(old_component, new_component)
        end

        if should_run do
          # For ticker-based watchers, send message to ticker
          # For immediate watchers, run the system
          case Map.get(watcher, :ticker) do
            nil ->
              # Immediate execution
              changes = build_changes(lifecycle_hook, old_component, new_component)
              watcher.system.process(entity, changes)

            _ticker_opts ->
              # Ticker-based execution handled by separate ticker process
              # This would be implemented in the Ticker module
              :ok
          end
        end
      end)
    end
  end

  defp build_changes(:attached, _old, new), do: %Changes{attached: [new]}
  defp build_changes(:updated, _old, new), do: %Changes{updated: [new]}
  defp build_changes(:removed, old, _new), do: %Changes{removed: [old.type]}
end
