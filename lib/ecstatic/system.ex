defmodule Ecstatic.System do
  @callback aspect() :: Aspect.t
  @callback dispatch(entity :: Ecstatic.Entity.t) :: Ecstatic.Changes.t
  defmacro __using__(_options) do
    quote do
      @behaviour Ecs.System
      alias Ecstatic.{Aspect, Changes, Component, Entity}

      @spec process(entity :: Entity.t) :: :ok
      def process(entity) do
        # TODO move this match_aspect? to the watcher definition?
        event = if Entity.match_aspect?(aspect(), entity) do
          {entity, dispatch(entity)}
        else
          {entity, %Changes{}}
        end
        EventQueue.push(event)
      end

    end
  end
end
