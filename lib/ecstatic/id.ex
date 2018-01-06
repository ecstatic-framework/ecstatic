defmodule Ecstatic.ID do
  @moduledoc false

  def new, do: UUID.uuid4()
end
