defmodule Ecstatic.Store.Ets do
  @behaviour Ecstatic.Store
  use GenServer

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    :ets.new(__MODULE__, [:named_table, :protected, :set])
    {:ok, opts}
  end

  def save_entity(entity) do
    GenServer.call(__MODULE__, {:save_entity, entity})
  end

  def delete_entity(id) do
    GenServer.cast(__MODULE__, {:delete_entity, id})
  end

  def get_entity(id) do
    [[entity]] = :ets.match(__MODULE__, {{:entity, id}, :"$1"})
    {:ok, entity}
  end

  def handle_call({:save_entity, entity}, _from, state) do
    :ets.insert(__MODULE__, {{:entity, entity.id}, entity})
    {:reply, {:ok, entity}, state}
  end

  def handle_cast({:delete_entity, id}, state) do
    :ets.match_delete(__MODULE__, {{:entity, id}, :"$1"})
    {:noreply, state}
  end
end
