defmodule GGARCRunner do
  def run(reqs, backing_store, capacity) do
    state = GGARC.State.new(capacity)

    {state, hits, misses, retrieval_cost} =
      Enum.reduce(reqs, {state, 0, 0, 0}, fn key, {state, hits, misses, cost} ->
        case GGARC.Algorithm.get(state, key) do
          {{:ok, _entry}, state} ->
            {state, hits + 1, misses, cost}

          {:miss, state} ->
            record = Map.fetch!(backing_store, key)

            metadata = %{
              latency_us: record.latency_us,
              memory_bytes: record.memory_bytes
            }

            state =
              GGARC.Algorithm.put(state, key, record.value, metadata)

            {state, hits, misses + 1, cost + record.latency_us}
        end
      end)

    %{
      hits: hits,
      misses: misses,
      hit_ratio: hits / length(reqs),
      retrieval_cost_us: retrieval_cost,
      stats: GGARC.Algorithm.stats(state)
    }
  end
end
