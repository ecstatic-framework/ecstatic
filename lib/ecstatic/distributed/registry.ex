defmodule Ecstatic.Distributed.Registry do
  @moduledoc """
  Distributed registry for entity location using Horde.

  This registry allows you to find any entity in the cluster by its ID,
  regardless of which node it's running on.
  """
  use Horde.Registry

  def start_link(_opts) do
    Horde.Registry.start_link(__MODULE__, [name: __MODULE__], name: __MODULE__)
  end

  def init(opts) do
    [members: members()]
    |> Keyword.merge(opts)
    |> Horde.Registry.init()
  end

  @doc """
  Lookup an entity by ID across the cluster.
  Returns the pid of the entity's GenServer.
  """
  def lookup(entity_id) do
    case Horde.Registry.lookup(__MODULE__, entity_id) do
      [{pid, _value}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Register an entity in the distributed registry.
  """
  def register(entity_id, value \\ nil) do
    Horde.Registry.register(__MODULE__, entity_id, value)
  end

  @doc """
  Get all members of the Horde registry cluster.
  """
  defp members do
    Enum.map([Node.self() | Node.list()], fn node ->
      {__MODULE__, node}
    end)
  end
end
