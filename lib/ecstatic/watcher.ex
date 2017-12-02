defmodule Ecstatic.Watcher do
  alias Ecstatic.Component, as: C

  defstruct [
    :component_type,
    :trigger,
    :system
  ]

  @type component_type :: atom()

  @type trigger :: [
    state: (C -> boolean())
  ] | [
    change: (C, C -> boolean())
  ] | [
    every: {integer(), :second | :seconds | :minute | :minutes | :hour | :hours}
  ]

  @type system :: atom()

  @type t :: %__MODULE__{
    component_type: atom(),
    trigger: trigger(),
    system: atom()
  }

  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :watchers, accumulate: true)
      @before_compile unquote(__MODULE__)
    end
  end
  defmacro __before_compile__(_env) do
    quote do
      def watchers, do: @watchers
    end
  end

  defmacro watch_component(comp, hook, callback, system) do
    x = Macro.escape(callback)
    quote do
      @watchers %{
        component: unquote(comp),
        hook: unquote(hook),
        callback: unquote(x),
        system: unquote(system)
      }
    end
  end
end
