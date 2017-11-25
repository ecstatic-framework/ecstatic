defmodule Ecstatic.Watcher do
  alias Ecstatic.Component, as: C

  defstruct [
    :component_type,
    :trigger,
    :system
  ]

  @type component_type :: atom()

  @type trigger :: [
    state: (C -> boolean())
  ] | [
    change: (C, C -> boolean())
  ] | [
    every: {integer(), :second | :seconds | :minute | :minutes | :hour | :hours}
  ]

  @type system :: atom()

  @type t :: %__MODULE__{
    component_type: atom(),
    trigger: trigger(),
    system: atom()
  }
end
