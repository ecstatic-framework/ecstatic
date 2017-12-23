defmodule Ecstatic.EventConsumer do
  use GenStage

  alias Ecstatic.Entity

  def start_link(entity) do
    GenStage.start_link(__MODULE__, entity)
  end

  def init(entity) do
    {
      :consumer,
      %{watchers: Application.get_env(:ecstatic, :watchers).()},
      subscribe_to: [
        {
          Ecstatic.EventProducer,
          selector: fn({event_entity, _event_comp}) ->
            event_entity.id == entity.id
          end,
          max_demand: 1,
          min_demand: 0
        }]
    }
  end

  # I can do [event] because I only ever ask for one.
  # event => {entity, %{changed: [], new: [], deleted: []}}
  def handle_events([{entity, changes} = _event], _from, %{watchers: watchers} = state) do
    watcher_should_trigger = watcher_should_trigger?(entity, changes)
    change_contains_component = change_contains_component?(changes)

    watchers_to_use =
      watchers
      |> Enum.filter(change_contains_component)
      |> Enum.filter(watcher_should_trigger)

    new_entity = Entity.apply_changes(entity, changes)
    #Ecstatic.Store.Ets.save_entity(new_entity)

    Enum.each(watchers_to_use, fn(w) ->
      w.system.process(new_entity)
    end)

    {:noreply, [], state}
  end

  def change_contains_component?(changes) do
    fn(watcher) ->
      changes
      |> Map.get(watcher.hook)
      |> Enum.map(&(&1.type))
      |> Enum.member?(watcher.component)
    end
  end

  def watcher_should_trigger?(entity, changes) do
    fn(watcher) ->
      watcher.callback.(
        entity,
        Enum.find(
          Map.get(changes, watcher.hook),
          fn(component) -> watcher.component == component.type end)
      )
    end
  end

end
