defmodule ARC.State do
  defstruct capacity: 100,
            p: 0,
            t1: %ARC.LRU{},
            t2: %ARC.LRU{},
            b1: %ARC.LRU{},
            b2: %ARC.LRU{}

  def new(capacity) when is_integer(capacity) and capacity > 0 do
    %__MODULE__{capacity: capacity}
  end
end
