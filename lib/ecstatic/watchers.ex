defmodule Ecstatic.Watchers do
  use Ecstatic.Watcher
  watch_component(Age, :attached, fn(_e, _c) -> true end, StartAgeTick)
  watch_component(Age, :removed, fn(_e, _c) -> false end, StopAgeTick)
end
