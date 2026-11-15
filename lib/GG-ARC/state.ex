defmodule GGARC.State do
  defstruct capacity: 100,
            request_count: 0,
            p: 0,
            t1: %GGARC.LRU{},
            t2: %GGARC.LRU{},
            b1: %GGARC.LRU{},
            b2: %GGARC.LRU{},
            w1: %{latency: 0.5, memory: 0.5},
            w2: %{latency: 0.5, memory: 0.5},
            latency_ref_us: 10_000,
            memory_ref_bytes: 65_536,
            eta: 0.05,
            protection_delta: 0.025,
            protection_max: 0.1,
            protection_half_life: 1000

  def new(capacity) when is_integer(capacity) and capacity > 0 do
    %__MODULE__{capacity: capacity}
  end
end
