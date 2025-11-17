defmodule Ecstatic.Distributed.Store do
  @moduledoc """
  Distributed store for querying entities across the cluster.

  Unlike the old ETS-based store, this uses Horde.Registry to find entities
  and can query them wherever they are in the cluster.

  For the POC, we keep queries simple. A production version could add:
  - Mnesia tables for efficient component-based queries
  - Caching layers
  - Component indices
  """

  alias Ecstatic.{Entity, Component}
  alias Ecstatic.Distributed.{Registry, EntityServer}

  @doc """
  Get an entity by ID from anywhere in the cluster.
  """
  @spec get_entity(Entity.id()) :: {:ok, Entity.t()} | {:error, :not_found}
  def get_entity(entity_id) do
    Entity.get(entity_id)
  end

  @doc """
  Delete an entity from the cluster.

  This terminates the entity's GenServer process.
  """
  @spec delete_entity(Entity.id()) :: :ok | {:error, term()}
  def delete_entity(entity_id) do
    case Registry.lookup(entity_id) do
      {:ok, pid} ->
        Ecstatic.Distributed.Supervisor.terminate_entity(pid)
        :ok

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  List all entities in the cluster.

  Returns entity IDs. To get full entity data, use get_entity/1 for each ID.

  Note: This is inefficient for large clusters. A production version would
  use Mnesia or another distributed store with better query capabilities.
  """
  @spec list_entities() :: [Entity.id()]
  def list_entities do
    Registry
    |> Horde.Registry.select([{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @doc """
  Query entities by component types.

  Returns entity IDs that have ALL of the specified components.

  Options:
  - `:with` - List of component types the entity must have
  - `:without` - List of component types the entity must NOT have

  ## Example

      Store.query(with: [Position, Velocity], without: [Frozen])

  Note: For POC, this fetches all entities and filters. A production version
  would use component indices in Mnesia for efficient queries.
  """
  @spec query(keyword()) :: [Entity.id()]
  def query(opts \\ []) do
    with_components = opts[:with] || []
    without_components = opts[:without] || []

    list_entities()
    |> Task.async_stream(
      fn entity_id ->
        case get_entity(entity_id) do
          {:ok, entity} ->
            has_required = Enum.all?(with_components, &Entity.has_component?(entity, &1))
            lacks_forbidden = !Enum.any?(without_components, &Entity.has_component?(entity, &1))

            if has_required && lacks_forbidden do
              {:ok, entity_id}
            else
              :skip
            end

          _ ->
            :skip
        end
      end,
      max_concurrency: 100,
      timeout: 5000
    )
    |> Enum.filter(&match?({:ok, {:ok, _}}, &1))
    |> Enum.map(fn {:ok, {:ok, entity_id}} -> entity_id end)
  end

  @doc """
  Get the count of entities in the cluster.
  """
  @spec count() :: non_neg_integer()
  def count do
    list_entities() |> length()
  end

  @doc """
  Check if an entity exists in the cluster.
  """
  @spec exists?(Entity.id()) :: boolean()
  def exists?(entity_id) do
    case Registry.lookup(entity_id) do
      {:ok, _pid} -> true
      _ -> false
    end
  end
end
