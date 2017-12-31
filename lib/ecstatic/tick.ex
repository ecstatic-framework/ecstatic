defmodule Ecstatic.NullSystem do
  use Ecstatic.System
  def aspect, do: %Aspect{}
  def dispatch(entity) do
    %Changes{}
  end
end
