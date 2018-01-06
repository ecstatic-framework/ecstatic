defmodule Ecstatic.NullSystem do
  @moduledoc false
  use Ecstatic.System
  def aspect, do: %Aspect{}
  def dispatch(entity) do
    %Changes{}
  end
end
