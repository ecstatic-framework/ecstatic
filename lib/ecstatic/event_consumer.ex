defmodule Ecstatic.EventConsumer do
  use GenStage

  def start_link(entity) do
    GenStage.start_link(__MODULE__, entity)
  end

  def init(entity) do
    {
      :consumer,
      nil,
      subscribe_to: [
        {
          Ecstatic.EventProducer,
          selector: fn({event_entity, event_comp}) ->
            event_entity.id == entity.id
          end,
          max_demand: 1,
          min_demand: 1
        }]
    }
  end

  # I can do [event] because I only ever ask for one.
  # event => {entity, %{changed: [], new: [], deleted: []}}
  def handle_events([{entity, changes} = _event], _from, nil) do
    watchers =
      Watchers.watchers
      |> Enum.map(&Map.put(&1, :used_this_round, false))

    filter_func = watcher_filter(entity, changes)

    watchers_to_use =
      watchers
      |> Enum.filter(&Enum.member?(Map.get(changes, &1.hook), &1.component))
      |> Enum.filter(&filter_func(&1))

    # Run through watchers; create internal loop
    # so they all have a chance to trigger, until no
    # more changes are detected
    {:noreply, [], nil}
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
