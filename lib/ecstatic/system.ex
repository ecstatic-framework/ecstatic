defmodule Ecstatic.System do
  @callback aspect() :: Aspect.t
  @callback dispatch(entity :: Ecstatic.Entity.t) :: [ Ecstatic.Component.t ]
  defmacro __using__(_options) do
    quote do
      @behaviour Ecs.System

      @spec process(entity :: Ecstatic.Entity.t) :: { Ecstatic.Entity.t, [ Ecstatic.Component.t ] }
      def process(entity) do
        if Ecstatic.Entity.match_aspect?(aspect(), entity) do
          {entity, dispatch(entity)}
        else
          {entity, []}
        end
      end

    end
  end
end
