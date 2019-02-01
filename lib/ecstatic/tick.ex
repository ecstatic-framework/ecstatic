defmodule Ecstatic.NullSystem do
  @moduledoc false
  use Ecstatic.System
  def aspect, do: %Aspect{}

  def dispatch(_entity) do
    %Changes{}
  end
end
