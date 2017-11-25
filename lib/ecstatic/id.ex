defmodule Ecstatic.ID do
  def new, do: UUID.uuid4()
end
