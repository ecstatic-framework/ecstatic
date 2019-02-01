defmodule Ecstatic.Changes do
  defstruct attached: [],
            updated: [],
            removed: []

  @type attached_component :: atom() | Ecstatic.Component.t()

  @type t :: %Ecstatic.Changes{
          attached: [attached_component],
          updated: [Ecstatic.Component.t()],
          removed: [atom()]
        }
end
