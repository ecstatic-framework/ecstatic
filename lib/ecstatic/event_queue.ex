defmodule Ecstatic.EventQueue do
  use GenServer

  def start_link(args \\ %{}), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  def init(args) do
    queue = :queue.new
    {:ok, %{queue: queue}}
  end

  def shift, do: GenServer.call(__MODULE__, :shift)
  def push(event), do: GenServer.call(__MODULE__, {:push, event})

  def handle_call(:shift, _from, %{queue: queue} = state) do
    case :queue.out(queue) do
      {:empty, _queue} -> {:reply, :no_events, state}
      {{:value, event}, new_queue} -> {:reply, event, %{state | queue: new_queue}}
    end
  end

  def handle_call({:push, event}, _from, %{queue: queue} = state) do
    {:reply, :ok, %{state | queue: :queue.in(event, queue)}}
  end
end
