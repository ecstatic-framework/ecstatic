defmodule Ecstatic.Watcher do
  defmacro __using__(_options) do
      Module.register_attribute(__CALLER__.module, :watchers, [accumulate: true])

    quote do
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end
  defmacro __before_compile__(env) do
    x = Module.get_attribute(env.module, :watchers)
    quote location: :keep do
      def watchers do
        unquote(x)
      end
    end
  end

  defmacro watch_component(comp, hook, callback, system) do
    map = quote do
      %{
        component: unquote(comp),
        hook: unquote(hook),
        callback: unquote(callback),
        system: unquote(system)
      }
    end
    Module.put_attribute(__CALLER__.module, :watchers, map)
    :ok
  end
end
