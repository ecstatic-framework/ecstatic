defmodule Ecstatic.Store do
  alias Ecstatic.Entity
  @type return_type :: {:ok, Entity.t()} | {:error, term()}
  @callback save_entity(Entity.t()) :: return_type
  @callback get_entity(pos_integer()) :: return_type
end
