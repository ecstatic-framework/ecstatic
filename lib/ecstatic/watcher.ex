defmodule Ecstatic.Watcher do
  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :watchers, [accumulate: true])
      @before_compile unquote(__MODULE__)
    end
  end
  defmacro __before_compile__(env) do
    quote location: :keep do
      def watchers do
        @watchers
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
    quote location: :keep do
      @watchers unquote(map)
    end
  end
end
