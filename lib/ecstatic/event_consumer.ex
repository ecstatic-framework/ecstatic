defmodule Ecstatic.EventConsumer do
  use GenStage

  def start_link(entity) do
    GenStage.start_link(__MODULE__, entity)
  end

  def init(entity) do
    {
      :consumer,
      entity,
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
  def handle_events([event], _from, orig_entity) do
    Watchers.watchers
    |> Enum.filter(%{}, fn({component, hook, callback, system}, acc) ->
      case hook do
        :created -> Enum.any?(event.new, &(&1 == component || (is_map(&1) == &1.type == component)))
        :updated -> Enum.any?(event.changed, &(&1 == component || (is_map(&1) == &1.type == component)))
        :deleted -> Enum.any?(event.deleted, &(&1 == component || (is_map(&1) == &1.type == component)))
        _ -> false
      end
    end)
    # Run through watchers; create internal loop
    # so they all have a chance to trigger, until no
    # more changes are detected
    {:noreply, [], orig_entity}
  end
end
