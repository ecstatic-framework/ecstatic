defmodule Ecstatic.Aspect do
  defstruct with: [],
            without: []

  @type t :: %Ecstatic.Aspect{
          with: [atom()],
          without: [atom()]
        }

  def new(with: with_components, without: without_components)
      when is_list(without_components)
      when is_list(with_components) do
    %Ecstatic.Aspect{
      with: with_components,
      without: without_components
    }
  end
end
