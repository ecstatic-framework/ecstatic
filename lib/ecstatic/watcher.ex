defmodule Ecstatic.Watcher do
  defmacro __using__(_options) do
    quote location: :keep do
      Module.register_attribute(__MODULE__, :watchers, [accumulate: true])
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

  defmacro watch_component(comp, run: system, every: milliseconds) do
    map = quote location: :keep do
      start_tick = fn(_e, c) ->
        Process.send_after(
          self(),
          {:tick, c.id, unquote(system), unquote(milliseconds)},
          unquote(milliseconds)
        )
        true
      end
      %{
        component: unquote(comp),
        hook: :attached,
        callback: start_tick,
        system: Ecstatic.NullSystem
      }
    end
    map2 = quote location: :keep do
      stop_tick = fn(_e, c) ->
        Process.send_after(self(), {:stop_tick, c.id}, 20)
        true
      end
      %{
        component: unquote(comp),
        hook: :removed,
        callback: stop_tick,
        system: Ecstatic.NullSystem
      }
    end
    quote location: :keep do
      @watchers unquote(Macro.escape(map))
      @watchers unquote(Macro.escape(map2))
    end
  end

  defmacro watch_component(comp, run: system, when: callback) do
    map = quote location: :keep do
      %{
        component: unquote(comp),
        hook: :updated,
        callback: unquote(callback),
        system: unquote(system)
      }
    end
    quote location: :keep do
      @watchers unquote(Macro.escape(map))
    end
  end
end
