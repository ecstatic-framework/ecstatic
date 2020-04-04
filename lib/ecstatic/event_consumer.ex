defmodule Ecstatic.EventConsumer do
  @moduledoc false
  use GenStage
  require Logger

  alias Ecstatic.Entity

  def start_link(entity) do
    GenStage.start_link(__MODULE__, entity)
  end

  def init(entity) do
    {:ok, ticker_pid} = Ecstatic.Ticker.start_link()
    state = %{
      watchers: Application.get_env(:ecstatic, :watchers).(),
      entity_id: entity.id,
      ticker: ticker_pid
    }

    {:consumer, state,
     subscribe_to: [
       {
         Ecstatic.EventProducer,
         selector: fn {event_entity, _changes} ->
           event_entity.id == entity.id
         end,
         max_demand: 1,
         min_demand: 0
       }
     ]}
  end

  # I can do [event] because I only ever ask for one.
  # event => {entity, %{changed: [], new: [], deleted: []}}
  def handle_events([{entity, changes} = _event], _from, %{ticker: ticker_pid, watchers: watchers} = state) do
    Logger.info(Kernel.inspect(changes, pretty: true))
    watcher_should_trigger = watcher_should_trigger?(entity, changes)
    change_contains_component = change_contains_component?(changes)

    watchers_to_use =
      watchers
      |> Enum.filter(change_contains_component)
      |> Enum.filter(watcher_should_trigger)

    new_entity = Entity.apply_changes(entity, changes)

    Enum.each(watchers_to_use, fn w ->
      case Map.get(w, :ticker, nil) do
        nil ->
          # TODO oh.. Does this mean I should create two types of systems
          # instead of having one system with dispatch/1 and dispatch/2 ?
          w.system.process(new_entity, changes)
        opts when is_list(opts) ->
          comp = Ecstatic.Entity.find_component(new_entity, w.component)
          case w.component_lifecycle_hook do 
            :updated ->
              case opts[:every] do 
                :continuous -> send(state.ticker, {:tick, comp.id, new_entity.id, w.system})
                t when is_number(t) -> 
                  Process.send_after(
                    state.ticker, 
                    {:tick, comp.id, new_entity.id, w.system}, 
                    t
                  )
              end
            :attached -> send(state.ticker, {:start_tick, comp.id, new_entity.id, w.system, opts})
            :removed -> send(state.ticker, {:stop_tick, comp.id})
          end
      end
    end)

    {:noreply, [], state}
  end

  def change_contains_component?(changes) do
    fn watcher ->
      changes
      |> Map.get(watcher.component_lifecycle_hook)
      |> Enum.map(& &1.type)
      |> Enum.member?(watcher.component)
    end
  end

  def watcher_should_trigger?(entity, changes) do
    fn watcher ->
      cond do 
        Map.get(watcher, :ticker, nil) != nil -> true
        Map.get(watcher, :callback, nil) != nil -> 
          watcher.callback.(
            entity,
            Enum.find(
              Map.get(changes, watcher.component_lifecycle_hook),
              fn component -> watcher.component == component.type end
            )
          )
      end
    end
  end

end
