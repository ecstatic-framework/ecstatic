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
    watchers = Module.delete_attribute(env.module, :watchers)

    foo =
      watchers
      |> Enum.map(fn(watcher) -> Map.update!(watcher, :callback, &(Code.eval_quoted(&1) |> elem(0))) end)

    quote location: :keep do
      def watchers do
        unquote(foo |> IO.inspect)
      end
    end
  end

  defmacro watch_component(comp, hook, callback, system) do
    x = Macro.escape(callback)
    map = quote do %{
      component: unquote(comp),
      hook: unquote(hook),
      callback: unquote(x),
      system: unquote(system)
    }
    end
    module = __CALLER__.module
    quote location: :keep do
      Module.put_attribute(unquote(module), :watchers, [
            unquote(map) | Module.get_attribute(unquote(module), :watchers)
          ])
    end
  end
end
