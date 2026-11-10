defmodule GGARC.State do
  defstruct capacity: 100,
            request_count: 0,
            p: 0,
            t1: %GGARC.LRU{},
            t2: %GGARC.LRU{},
            b1: %GGARC.LRU{},
            b2: %GGARC.LRU{}

  def new(capacity) when is_integer(capacity) and capacity > 0 do
    %__MODULE__{capacity: capacity}
  end
end
