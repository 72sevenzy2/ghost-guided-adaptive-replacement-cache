defmodule ARCRunner do
  alias ARC.{Algorithm, State}

  def run(requests, backing_store, capacity) do
    initial_state = State.new(capacity)

    {state, hits, misses, retrieval_cost_us} =
      Enum.reduce(requests, {initial_state, 0, 0, 0}, fn key, {state, hits, misses, cost} ->
        case Algorithm.get(state, key) do
          {{:ok, _value}, state} ->
            {state, hits + 1, misses, cost}

          {:miss, state} ->
            record = Map.fetch!(backing_store, key)

            state = Algorithm.put(state, key, record.value)

            {state, hits, misses + 1, cost + record.latency_us}
        end
      end)

    hit_total = hits + misses

    %{
      hits: hits,
      misses: misses,
      hit_ratio: if(hit_total == 0, do: 0.0, else: hits / hit_total),
      retrieval_cost_us: retrieval_cost_us,
      stats: Algorithm.stats(state)
    }
  end
end
