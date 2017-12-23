defmodule Ecstatic.System do
  @callback aspect() :: Aspect.t
  @callback dispatch(entity :: Ecstatic.Entity.t) :: Ecstatic.Changes.t
  defmacro __using__(_options) do
    quote location: :keep do
      @behaviour Ecstatic.System
      alias Ecstatic.{Aspect, Changes, Component, Entity, EventQueue}

      @spec process(entity :: Entity.t) :: :ok
      def process(entity) do
        # TODO move this match_aspect? to the watcher definition?
        event = if Entity.match_aspect?(entity, aspect()) do
          {entity, dispatch(entity)}
        else
          {entity, %Changes{}}
        end
        EventQueue.push(event)
      end

    end
  end
end
