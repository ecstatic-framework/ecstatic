defmodule Ecstatic.NullSystem do
  @moduledoc false
  use Ecstatic.System
  def aspect, do: %Aspect{}

  def dispatch(_entity) do
    %Changes{}
  end

  def dispatch(_entity, _changes) do
    %Changes{}
  end
end
