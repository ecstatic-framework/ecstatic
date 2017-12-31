defmodule Ecstatic.System do
  alias Ecstatic.{Aspect, Changes, Entity}
  @callback aspect() :: Aspect.t
  @callback dispatch(entity :: Entity.t) :: Changes.t
  defmacro __using__(_options) do
    quote location: :keep do
      @behaviour Ecstatic.System
      alias Ecstatic.{Aspect, Changes, Component, Entity, EventSource}

      @spec process(entity :: Entity.t) :: :ok
      def process(entity) do
        event = if Entity.match_aspect?(entity, aspect()) do
          {entity, dispatch(entity)}
        else
          {entity, %Changes{}}
        end
        EventSource.push(event)
      end

    end
  end
end
