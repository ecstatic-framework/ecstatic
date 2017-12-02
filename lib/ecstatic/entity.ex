defmodule Ecstatic.Entity do
  alias Ecstatic.{Entity, Component, Aspect, Changes, Store}
  defstruct [:id, components: []]

  @type id :: String.t
  @type uninitialized_component :: atom()
  @type components :: list(Component.t)
  @type t :: %Entity{
    id: String.t,
    components: components
  }

  @callback default_components() :: [ atom() ]

  defmacro __using__(_options) do
    quote do
      @behaviour Entity
    end
  end

  def default_components, do: []

  @doc "Creates a new entity"
  @spec new(components) :: t
  def new(components) when is_list(components) do
    entity = build(components ++ default_components())
    Ecstatic.EventConsumer.start_link(entity)
    entity
  end

  @spec new(uninitialized_component) :: t
  def new(component), do: new([component])

  @spec new :: t
  def new, do: new(default_components())

  defp build(components) do
    # TODO deduplicate components; prefer initialized components.
    entity = %Entity{id: id()}
    Store.Ets.save_entity(entity)
    Ecstatic.EventQueue.push({entity, %Ecstatic.Changes{attached: components}})
    entity
    # Enum.reduce(components, entity, fn
    #   (%Component{} = comp, acc) -> Entity.add(acc, comp)
    #   (comp, acc) when is_atom(comp) -> Entity.add(acc, comp.new)
    #   (comp, _acc) -> raise "Could not initialize, #{inspect comp} is not a component."
    # end)
  end

  def id, do: Ecstatic.ID.new

  @doc "Add an initialized component to an entity"
  @spec add(t, Component.t) :: t
  def add(%Entity{} = entity, %Component{} = component) do
    Ecstatic.EventQueue.push({entity, %Ecstatic.Changes{attached: [component]}})
    # new_entity = %{entity | components: [component | components]}
    # Store.Ets.save_entity(new_entity)
    entity
  end

  @doc "Checks if an entity matches an aspect"
  @spec match_aspect?(t, Aspect.t) :: boolean
  def match_aspect?(entity, aspect) do
    Enum.all?(aspect.with, &has_component?(entity, &1)) &&
      ! Enum.any?(aspect.without, &has_component?(entity, &1))
  end

  @doc "Check if an entity has an instance of a given component"
  @spec has_component?(t, uninitialized_component) :: boolean
  def has_component?(entity, component) do
    entity.components
    |> Enum.map(&(&1.type))
    |> Enum.member?(component)
  end

  @spec find_component(t, uninitialized_component) :: Component.t | nil
  def find_component(entity, component) do
    Enum.find(entity.components, &(&1.type == component))
  end

  @spec apply_changes(t, Changes.t) :: t
  def apply_changes(entity, %Changes{
        attached: attached,
        updated: updated,
        removed: removed}) do
    comps_to_attach = Enum.map(attached, fn
      c when is_atom(c) -> c.new
      c -> c
    end)
    new_comps =
      updated
      |> Enum.concat(entity.components)
      |> Enum.uniq_by(&(&1.id))
      |> Enum.concat(comps_to_attach)
      |> Enum.uniq_by(&(&1.type))
      |> Enum.reject(&Enum.member?(removed, &1.type))
    new_entity = %{entity | components: new_comps}
    Store.Ets.save_entity(new_entity)
  end

end
