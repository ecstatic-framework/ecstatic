defmodule Ecstatic.Store do 
  alias Ecstatic.Entity

  @type return_type :: {:ok, Entity.t()} | {:error, term()}
  @type entity_id_type :: pos_integer() | String.t()
  @callback save_entity(Entity.t()) :: return_type
  @callback get_entity(entity_id_type) :: return_type
  @callback delete_entity(entity_id_type) :: none()
end
