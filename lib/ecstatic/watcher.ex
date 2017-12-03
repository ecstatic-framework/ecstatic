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
      Module.register_attribute(__MODULE__, :watchers, [])
      Module.put_attribute(__MODULE__, :watchers, [])
      @before_compile unquote(__MODULE__)
    end
  end
  defmacro __before_compile__(env) do
    x = Enum.map(
      Module.get_attribute(env.module, :watchers),
      fn(watcher) ->
        Map.update!(
          watcher, :callback,
          fn(callback) ->
            IO.inspect(quote do unquote(callback) end)
          end)
    end)
    Module.put_attribute(
      env.module,
      :watchers,
      x)
    quote do
      def watchers, do: @watchers
    end
  end

  defmacro watch_component(comp, hook, callback, system) do
    x = Macro.escape(callback)
    quote location: :keep do
      Module.put_attribute(__MODULE__, :watchers, [
            %{
              component: unquote(comp),
              hook: unquote(hook),
              callback: unquote(x),
              system: unquote(system)
            } | Module.get_attribute(__MODULE__, :watchers)])
    end
  end
end
