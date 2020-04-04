defmodule Ecstatic.Ticker do
  defstruct [
    ticks: %{}
  ]
  use GenServer

  def start_link(), do: start_link(nil)
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_opts) do 
    {:ok, %Ecstatic.Ticker{}}
  end

  defp update_ticks(state, c_id, tick) do
    new_ticks = Map.put(state.ticks, c_id, tick)
    Map.put(state, :ticks, new_ticks)
  end
  
  def handle_info({:tick, c_id, e_id, system}, state) do
    case Map.get(state.ticks, c_id, nil) do
      t_left 
        when t_left == :infinity 
        when (is_number(t_left) and t_left > 0) ->

          {:ok, entity} = Ecstatic.Store.Ets.get_entity(e_id)
          system.process(entity)

          case t_left do 
            :infinity -> {:noreply, state}
            _ -> {:noreply, update_ticks(state, c_id, (t_left - 1))}
          end
      0 ->
        {:noreply, update_ticks(state, c_id, :stopped)}
      :stopped -> 
        {:noreply, state}
    end
  end

  def handle_info({:start_tick, c_id, e_id, system, [every: _interval, for: ticks]}, state) do
    send(self(), {:tick, c_id, e_id, system})
    {:noreply, update_ticks(state, c_id, ticks)}
  end

  def handle_info({:stop_tick, c_id}, state) do
    {:noreply, update_ticks(state, c_id, :stopped)}
  end
end
