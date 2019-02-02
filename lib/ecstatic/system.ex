defmodule Ecstatic.System do
  alias Ecstatic.{Aspect, Changes, Entity}
  @callback aspect() :: Aspect.t()
  @doc "this is a test"
  @callback dispatch(entity :: Entity.t(), optional_change) :: Changes.t()

  @type optional_change :: Changes.t() | nil

  @doc false
  defmacro __using__(_options) do
    quote location: :keep do
      @behaviour Ecstatic.System
      alias Ecstatic.{Aspect, Changes, Component, Entity, EventSource}

      @type dispatch_fun ::
              (Entity.t() -> Changes.t())
              | (Entity.t(), Changes.t() -> Changes.t())
      @type event_push :: :ok

      def process(entity, changes \\ nil)

      @spec process(entity :: Entity.t(), nil) :: event_push()
      def process(entity, nil) do
        function = fn -> dispatch(entity) end
        do_process(entity, function)
      end

      @spec process(entity :: Entity.t(), changes :: Changes.t()) :: event_push()
      def process(entity, changes) do
        function = fn -> dispatch(entity, changes) end
        do_process(entity, function)
      end

      @spec do_process(Entity.t(), dispatch_fun()) :: event_push()
      def do_process(entity, function) do
        event =
          if Entity.match_aspect?(entity, aspect()) do
            {entity, function.()}
          else
            {entity, %Changes{}}
          end

        EventSource.push(event)
      end
    end
  end
end
