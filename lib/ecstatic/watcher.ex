defmodule Ecstatic.Watcher do
  @doc false
  defmacro __using__(_options) do
    quote do
      Module.register_attribute(__MODULE__, :watchers, accumulate: true)
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    quote do
      def watchers do
        unquote(Module.get_attribute(env.module, :watchers))
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
    map =
      quote do
        %{
          callback: unquote(predicate),
          component: @current_component,
          component_lifecycle_hook: :updated,
          system: unquote(system)
        }
      end

    quote do
      @watchers unquote(Macro.escape(map))
    end
  end
end

# defmacro run(system, every: milliseconds) do
#   map =
#     quote location: :keep do
#       component = Module.get_attribute(__MODULE__, :current_component)

#       if component == nil do
#         raise "run/2 cannot be called outside a watch/2 macro code block"
#       end

#       start_tick = fn _e, c ->
#         Process.send_after(
#           self(),
#           {:tick, c.id, unquote(system), unquote(milliseconds)},
#           unquote(milliseconds)
#         )

#         true
#       end

#       %{
#         component: component,
#         component_lifecycle_hook: :attached,
#         callback: start_tick,
#         system: Ecstatic.NullSystem
#       }
#     end

#   map2 =
#     quote location: :keep do
#       component = Module.get_attribute(__MODULE__, :current_component)

#       if component == nil do
#         raise "run/2 cannot be called outside a watch/2 macro code block"
#       end

#       stop_tick = fn _e, c ->
#         Process.send_after(self(), {:stop_tick, c.id}, 20)
#         true
#       end

#       %{
#         component: component,
#         component_lifecycle_hook: :removed,
#         callback: stop_tick,
#         system: Ecstatic.NullSystem
#       }
#     end

#   quote location: :keep, bind_quoted: [map: map, map2: map2] do
#     @watchers unquote(Macro.escape(map))
#     @watchers unquote(Macro.escape(map2))
#   end
# end
