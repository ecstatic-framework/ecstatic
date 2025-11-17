defmodule Ecstatic.Distributed.Supervisor do
  @moduledoc """
  Distributed supervisor for entities using Horde.

  This supervisor automatically distributes entities across the cluster
  and handles failover when nodes join or leave.
  """
  use Horde.DynamicSupervisor

  def start_link(_opts) do
    Horde.DynamicSupervisor.start_link(__MODULE__, [name: __MODULE__], name: __MODULE__)
  end

  def init(opts) do
    [
      strategy: :one_for_one,
      members: members(),
      distribution_strategy: Horde.UniformQuorumDistribution
    ]
    |> Keyword.merge(opts)
    |> Horde.DynamicSupervisor.init()
  end

  @doc """
  Start an entity under distributed supervision.
  """
  def start_entity(child_spec) do
    Horde.DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Terminate an entity.
  """
  def terminate_entity(pid) when is_pid(pid) do
    Horde.DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  @doc """
  Get all members of the Horde supervisor cluster.
  """
  defp members do
    Enum.map([Node.self() | Node.list()], fn node ->
      {__MODULE__, node}
    end)
  end
end
