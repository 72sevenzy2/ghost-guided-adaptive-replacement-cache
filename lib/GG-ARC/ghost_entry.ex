defmodule GGARC.GhostEntry do
  defstruct [
    :latency_us,
    :memory_bytes,
    protection: 0.0,
    protection_at: 0
  ]
end
