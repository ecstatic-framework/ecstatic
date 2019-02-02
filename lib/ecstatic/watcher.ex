defmodule Ecstatic.Watcher do
  @doc false
  defmacro __using__(_options) do
    quote location: :keep do
      Module.register_attribute(__MODULE__, :watchers, accumulate: true)
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote location: :keep do
      @watchers
      def watchers do
        Code.eval_quoted @watchers
      end
    end
  end

  defmacro watch(component, do: systems_code_block) do
    quote do
      Module.put_attribute(__MODULE__, :current_component, unquote(component))
      unquote(systems_code_block)
      Module.delete_attribute(__MODULE__, :current_component)
    end
  end

  defmacro run(system, when: predicate) do
    x =
      quote location: :keep do
        Module.get_attribute(__MODULE__, :current_component)
      end

    y =
      quote location: :keep do
        if unquote(x) == nil do
          raise "run/2 cannot be called outside a watch/2 macro code block"
        end

        watch_component(unquote(x), run: unquote(system), when: unquote(predicate))
      end


  end

  defmacro run(system, every: milliseconds) do
    x =
      quote location: :keep do
        Module.get_attribute(__MODULE__, :current_component)
      end

    y =
      quote location: :keep do
        if unquote(x) == nil do
          raise "run/2 cannot be called outside a watch/2 macro code block"
        end

        watch_component(unquote(x), run: unquote(system), every: unquote(milliseconds))
      end

    Macro.expand(y, __ENV__)
  end

  defmacro watch_component(comp, run: system, when: predicate) do
    map =
      quote location: :keep do
        %{
          component: unquote(comp),
          component_lifecycle_hook: :updated,
          callback: unquote(predicate),
          system: unquote(system)
        }
      end

    quote location: :keep do
      @watchers unquote(Macro.escape(map))
    end
  end

  defmacro watch_component(comp, run: system, every: milliseconds) do
    map =
      quote location: :keep do
        start_tick = fn _e, c ->
          Process.send_after(
            self(),
            {:tick, c.id, unquote(system), unquote(milliseconds)},
            unquote(milliseconds)
          )

          true
        end

        %{
          component: unquote(comp),
          component_lifecycle_hook: :attached,
          callback: start_tick,
          system: Ecstatic.NullSystem
        }
      end

    map2 =
      quote location: :keep do
        stop_tick = fn _e, c ->
          Process.send_after(self(), {:stop_tick, c.id}, 20)
          true
        end

        %{
          component: unquote(comp),
          component_lifecycle_hook: :removed,
          callback: stop_tick,
          system: Ecstatic.NullSystem
        }
      end

    quote location: :keep do
      @watchers unquote(Macro.escape(map))
      @watchers unquote(Macro.escape(map2))
    end
  end
end
