defmodule Ecstatic.Entity do

  defstruct [:id, components: []]

  @type id :: String.t
  @type uninitialized_component :: atom()
  @type components :: list(Ecs.Component.t)
  @type t :: %Ecs.Entity{
    id: String.t,
    components: components
  }

  def default_components: []

  @doc "Creates a new entity"
  @spec new(components) :: t
  def new(components: components) when is_list(components) do
    {:ok, pid} = GenServer.start(__MODULE__, components)
    GenServer.call(pid, :entity)
  end
  def new(components) when is_list(components), do: new(components: components)

  @spec new(uninitialized_component) :: t
  def new(component), do: new(components: [component | ])

  @spec new :: t
  def new, do: new(components: default_components())

  defp build(components) do
    entity = %Ecs.Entity{id: id()}
    Enum.reduce(components, entity, fn
      (%Ecs.Component{} = c, acc) -> Ecs.Entity.add(entity, c)
      (c, acc) when is_atom(c) -> Ecs.Entity.add(entity, c.new)
      (c, acc) -> raise Ecs.InvalidComponentError, c
    end)
  end

  def id, do: UUID.uuid4(:hex)

  @doc "Add an initialized component to an entity"
  @spec add(t, Ecs.Component.t) :: t
  def add(%Ecs.Entity{components: components} = entity, %Ecs.Component{} = component) do
    start_timer_for_component(component, repeat: false)
    %{entity | components: [component | components]}
  end

  @doc "Checks if an entity matches an aspect"
  @spec match_aspect?(t, Ecs.Aspect.t) :: boolean
  def match_aspect?(entity, aspect) do
    Enum.all?(aspect.with, &has_component?(entity, &1)) &&
      ! Enum.any?(aspect.without, &has_component?(entity, &1))
  end
end
