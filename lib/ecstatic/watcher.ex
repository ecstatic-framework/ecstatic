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
      Module.put_attribute(__MODULE__, :current_component, nil)
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


  defguard is_tick(ticks) when (is_number(ticks) and ticks > 0) or ticks == :infinity
  defguard is_interval(interval) when (is_number(interval) and interval > 0) or interval == :continuous

  defp run_ticker(system, [every: interval, for: ticks] = ticker_opts) 
    when is_tick(ticks) and is_interval(interval) do
    attached = 
      quote location: :keep do
        component = Module.get_attribute(__MODULE__, :current_component)
        %{
          component: component,
          component_lifecycle_hook: :attached,
          system: unquote(system),
          ticker: unquote(ticker_opts)
        }
      end

    removed = 
      quote location: :keep do 
        component = Module.get_attribute(__MODULE__, :current_component)
        %{
          component: component,
          component_lifecycle_hook: :removed,
          system: unquote(system),
          ticker: unquote(ticker_opts)
        }
      end

    quote location: :keep, bind_quoted: [attached: attached, removed: removed] do
      @watchers Macro.escape(attached)
      @watchers Macro.escape(removed)
    end
  end

  # reactive (event-driven) run macro
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

  # ticker-based run macros
  defmacro run(system, :continuous), do: run_ticker(system, [every: :continuous, for: :infinity])
  defmacro run(system, [every: interval]), do: run_ticker(system, [every: interval, for: :infinity])
  defmacro run(system, [every: interval, for: ticks]), do: run_ticker(system, [every: interval, for: ticks])

end

