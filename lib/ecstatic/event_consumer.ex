defmodule Ecstatic.EventConsumer do
  use GenStage

  alias Ecstatic.{Entity, Watchers}

  def start_link(entity) do
    GenStage.start_link(__MODULE__, entity)
  end

  def init(entity) do
    {
      :consumer,
      :ok,
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
  def handle_events([{entity, changes} = _event], _from, :ok) do
    watchers =
      Watchers.watchers
      |> Enum.map(&Map.put(&1, :used_this_round, false))

    filter_func = watcher_filter(entity, changes)

    IO.inspect changes

    watchers_to_use =
      watchers
      |> Enum.filter(&Enum.member?(Map.get(changes, &1.hook), &1.component))
      |> Enum.filter(filter_func)

    new_entity = Entity.apply_changes(entity, changes)
    #Ecstatic.Store.Ets.save_entity(new_entity)

    Enum.each(watchers_to_use, fn(w) ->
      w.system.process(new_entity)
    end)

    {:noreply, [], :ok}
  end

  def watcher_filter(entity, changes) do
    fn(watcher) ->
      watcher.callback(
        entity,
        Enum.find(
          Map.get(changes, watcher.hook),
          watcher.component)
      )
    end
  end

end
