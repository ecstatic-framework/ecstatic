defmodule DistributedGame.Components do
  @moduledoc """
  Components for the distributed game example.
  """

  defmodule Health do
    use Ecstatic.Component

    @default_state %{points: 100, max_points: 100}
  end

  defmodule Position do
    use Ecstatic.Component

    @default_state %{x: 0.0, y: 0.0}
  end

  defmodule Velocity do
    use Ecstatic.Component

    @default_state %{dx: 0.0, dy: 0.0}
  end

  defmodule Damage do
    use Ecstatic.Component

    @default_state %{points: 10}
  end

  defmodule Team do
    use Ecstatic.Component

    @default_state %{name: :neutral}
  end

  defmodule Name do
    use Ecstatic.Component

    @default_state %{value: "Unnamed"}
  end
end
