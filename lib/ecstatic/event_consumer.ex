defmodule Ecstatic.EventConsumer do
  @moduledoc false
  use GenStage

  alias Ecstatic.Entity

  def start_link(entity) do
    GenStage.start_link(__MODULE__, entity)
  end

  def init(entity) do
    state = %{
      watchers: Application.get_env(:ecstatic, :watchers).(),
      entity_id: entity.id,
      ticks: %{}}
    {
      :consumer, state, subscribe_to: [{
                                        Ecstatic.EventProducer,
                                        selector: fn({event_entity, _changes}) ->
                                          event_entity.id == entity.id
                                        end,
                                        max_demand: 1,
                                        min_demand: 0
                                        }]}
  end

  # I can do [event] because I only ever ask for one.
  # event => {entity, %{changed: [], new: [], deleted: []}}
  def handle_events([{entity, changes} = _event], _from, %{watchers: watchers} = state) do
    IO.inspect changes
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

  def handle_info({:tick, c_id, system, ms}, state) do
    case Map.get(state.ticks, c_id, :no_tick) do
      :no_tick ->
        {:ok, entity} = Ecstatic.Store.Ets.get_entity(state.entity_id)
        system.process(entity)
        Process.send_after(
          self(),
          {:tick, c_id, system, ms},
          ms
        )
        {:noreply, [], put_in(state, [:ticks, c_id], true)}
      true ->
        {:ok, entity} = Ecstatic.Store.Ets.get_entity(state.entity_id)
        system.process(entity)
        Process.send_after(
          self(),
          {:tick, c_id, system, ms},
          ms
        )
        {:noreply, [], state}
      false ->
        ticks = Map.delete(state.ticks, c_id)
        {:noreply, [], Map.put(state, :ticks, ticks)}
    end
  end

  def handle_info({:stop_tick, c_id}, state) do
    {:noreply, [], put_in(state, [:ticks, c_id], false)}
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
