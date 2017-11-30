defmodule Ecstatic.EventProducer do
  use GenStage

  def start_link() do
    GenStage.start_link(__MODULE__, EventQueue)
  end

  def init(event_source) do
    {:producer, %{source: event_source, demand: 0}, dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_demand(demand, state) when demand > 0 do
    {to_produce, new_state} = fetch(demand + state.demand, state)
    {:noreply, Enum.reverse(to_produce), new_state}
  end

  defp fetch(demand, state) do
    fetch_aux(demand, state, [])
  end
  defp fetch_aux(0, state, acc), do: {acc, %{state | demand: 0}}
  defp fetch_aux(demand, state, acc) do
    case state.source.shift do
      :no_events -> {acc, %{state | demand: demand}}
      event -> fetch_aux(demand - 1, state, [event | acc])
    end
  end
end
