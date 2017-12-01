defmodule Ecstatic.Changes do
  defstruct [
    attached: [],
    updated: [],
    removed: [],
  ]

  @type t :: %Ecstatic.Changes{
    attached: [ atom() ],
    updated: [ Ecstatic.Component.t ],
    removed: [ atom() ]
  }
end
