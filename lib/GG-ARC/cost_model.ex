defmodule GGARC.CostModel do
  alias GGARC.{Entry, State}

  def normalise_latency(latency, reference)
      when is_number(latency) and latency >= 0 and is_number(reference) and reference > 0 do
    min(
      :math.log(1 + latency) / :math.log(1 + reference),
      1.0
    )
  end

  def normalise_memory(memory, reference)
      when is_number(memory) and memory >= 0 and is_number(reference) and reference > 0 do
    min(memory / reference, 1.0)
  end

  def score(%Entry{} = entry, weights, %State{} = state, effective_protection) do
    latency =
      normalise_latency(entry.latency_us, state.latency_ref_us)

    memory =
      normalise_memory(entry.memory_bytes, state.memory_ref_bytes)

    weights.latency * latency - weights.memory * memory + effective_protection
  end
end
