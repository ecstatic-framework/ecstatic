defmodule DistributedGame.Entities do
  @moduledoc """
  Entity definitions for the distributed game.
  """

  alias DistributedGame.Components.{Health, Position, Velocity, Damage, Team, Name}

  defmodule Player do
    use Ecstatic.Entity

    @default_components [Health, Position, Velocity, Damage]
  end

  defmodule Enemy do
    use Ecstatic.Entity

    @default_components [Health, Position, Velocity, Damage, Team]
  end

  defmodule PowerUp do
    use Ecstatic.Entity

    @default_components [Position]
  end

  @doc """
  Create a player entity with custom attributes.
  """
  def create_player(name, opts \\ []) do
    Player.new([
      Name.new(%{value: name}),
      Team.new(%{name: :player}),
      Health.new(%{points: opts[:health] || 100, max_points: 100}),
      Position.new(%{x: opts[:x] || 0.0, y: opts[:y] || 0.0}),
      Velocity.new(%{dx: opts[:dx] || 0.0, dy: opts[:dy] || 0.0}),
      Damage.new(%{points: opts[:damage] || 15})
    ])
  end

  @doc """
  Create an enemy entity.
  """
  def create_enemy(name, opts \\ []) do
    Enemy.new([
      Name.new(%{value: name}),
      Team.new(%{name: :enemy}),
      Health.new(%{points: opts[:health] || 50, max_points: 50}),
      Position.new(%{x: opts[:x] || :rand.uniform() * 100, y: opts[:y] || :rand.uniform() * 100}),
      Velocity.new(%{dx: :rand.uniform() * 2 - 1, dy: :rand.uniform() * 2 - 1}),
      Damage.new(%{points: opts[:damage] || 5})
    ])
  end

  @doc """
  Create a power-up entity.
  """
  def create_powerup(opts \\ []) do
    PowerUp.new([
      Position.new(%{x: opts[:x] || :rand.uniform() * 100, y: opts[:y] || :rand.uniform() * 100})
    ])
  end
end
