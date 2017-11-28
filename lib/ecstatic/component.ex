defmodule Ecstatic.Component do
  alias Ecstatic.Component
  defstruct [:id, :state, :type]

  @type params :: map()
  @type id :: String.t
  @type component_type :: atom()
  @type state :: map()
  @type t :: %Component{
    type: component_type,
    state: state,
    id: id
  }

  @callback default_value :: map()

  defmacro __using__(_options) do
    quote do
      @behaviour Component
      def new(initial_state \\ %{}) do
        Component.new(
          __MODULE__,
          Map.merge(default_value(), initial_state)
        )
      end
    end
  end

  @doc "New component"
  @spec new(component_type, state) :: t
  def new(component_type, initial_state) do
    id = Ecstatic.ID.new
    struct(
      __MODULE__,
      %{id: id, type: component_type, state: initial_state}
    )
  end
end
