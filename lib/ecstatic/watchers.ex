defmodule Ecstatic.Watchers do
  use Ecstatic.Watcher
  watch_component(Age, :attach, fn(_e, _c) -> true end, StartAgeTick)
  watch_component(Age, :detach, fn(_e, _c) -> false end, StopAgeTick)
end
