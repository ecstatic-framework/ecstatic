defmodule Ecstatic.EventSource do
  @moduledoc false
  use GenStage

  def start_link(args \\ %{}), do: GenStage.start_link(__MODULE__, args, name: __MODULE__)

  def init(_args) do
    queue = :queue.new
    {:producer, %{queue: queue, demand: 0}, dispatcher: GenStage.BroadcastDispatcher}
  end

  def push(event), do: GenServer.call(__MODULE__, {:push, event})

  def handle_demand(demand, %{queue: _q} = state) when demand > 0 do
    {to_produce, new_state} = fetch(demand + state.demand, state)
    {:noreply, Enum.reverse(to_produce), new_state}
  end

  def handle_call({:push, event}, _from, %{queue: queue} = state) do
    new_queue = :queue.in(event, queue)
    {to_produce, new_state} = fetch(state.demand, %{state | queue: new_queue})
    {:reply, :ok, Enum.reverse(to_produce), new_state}
  end

  defp fetch(demand, state) do
    fetch_aux(demand, state, [])
  end
  defp fetch_aux(0, state, acc), do: {acc, %{state | demand: 0}}
  defp fetch_aux(demand, state, acc) do
    case shift(state.queue) do
      :no_events -> {acc, %{state | demand: demand}}
      {event, queue} -> fetch_aux(demand - 1, %{state | queue: queue}, [event | acc])
    end
  end

  defp shift(queue) do
    case :queue.out(queue) do
      {:empty, new_queue} -> :no_events
      {{:value, event}, new_queue} -> {event, new_queue}
    end
  end
end
