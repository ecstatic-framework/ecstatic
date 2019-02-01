defmodule Ecstatic.EventProducer do
  @moduledoc false
  alias Ecstatic.EventSource
  use GenStage

  def start_link(_args \\ %{}) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {
      :producer_consumer,
      %{demand: 0, events: []},
      dispatcher: GenStage.BroadcastDispatcher, subscribe_to: [EventSource]
    }
  end

  def handle_demand(demand, state) when demand > 0 do
    total_demand = demand + state.demand
    {to_produce, new_state} = fetch(total_demand, state)
    {:noreply, to_produce, new_state}
  end

  def handle_events(events, _from, state) do
    {:noreply, events, state}
  end

  defp fetch(demand, state) do
    {events_to_produce, events_left} = Enum.split(state.events, demand)
    remaining_demand = demand - length(events_to_produce)

    new_state =
      state
      |> Map.put(:events, events_left)
      |> Map.put(:demand, remaining_demand)

    {events_to_produce, new_state}
  end
end
