defmodule GGARC.Algorithm do
  alias GGARC.{LRU, State, Entry, GhostEntry, Protection, CostModel}

  def get(state, key) do
    state = %{state | request_count: state.request_count + 1}

    cond do
      match?({:ok, _}, LRU.get(state.t1, key)) ->
        {:ok, value} = LRU.get(state.t1, key)

        state = %{
          state
          | t1: LRU.delete(state.t1, key),
            t2: LRU.put(state.t2, key, value)
        }

        {{:ok, value}, state}

      match?({:ok, _}, LRU.get(state.t2, key)) ->
        {:ok, value} = LRU.get(state.t2, key)

        state = %{
          state
          | t2: LRU.put(state.t2, key, value)
        }

        {{:ok, value}, state}

      true ->
        {:miss, state}
    end
  end

  def put(state, key, value, metadata) do
    latency = Map.fetch!(metadata, :latency_us)
    memory = Map.fetch!(metadata, :memory_bytes)

    cond do
      match?({:ok, _}, LRU.get(state.t1, key)) ->
        {:ok, entry} = LRU.get(state.t1, key)
        entry = %{entry | value: value}

        %{
          state
          | t1: LRU.delete(state.t1, key),
            t2: LRU.put(state.t2, key, entry)
        }

      match?({:ok, _}, LRU.get(state.t2, key)) ->
        {:ok, entry} = LRU.get(state.t2, key)

        %{state | t2: LRU.put(state.t2, key(%{entry | value: value}))}

      match?({:ok, _}, LRU.get(state.b1, key)) ->
        {:ok, ghost} = LRU.get(state.b1, key)

        state = adjust_parameter_up(state, state.b1, state.b2)
        state = %{state | b1: LRU.delete(state.b1, key)}

        state = replace(state, key)
        state = %{state | b1: LRU.delete(state.b1, key)}

        entry = restore_entry(ghost, value, latency, memory, state)

        %{state | t2: LRU.put(state.t2, key, entry)}

      match?({:ok, _}, LRU.get(state.b2, key)) ->
        {:ok, ghost} = LRU.get(state.b2, key)

        state = adjust_parameter_down(state, state.b1, state.b2)
        state = adapt_weights(state, ghost, :t2)

        state = replace(state, key)
        state = %{state | b2: LRU.delete(state.b2, key)}

        entry = restore_entry(ghost, value, latency, memory, state)

        %{state | t2: LRU.put(state.t2, key, value)}

      true ->
        insert_new(state, key, value, latency, memory)
    end
  end

  defp restore_entry(ghost, value, latency, memory, state) do
    %Entry{
      value: value,
      latency_us: latency,
      memory_bytes: memory,
      protection: ghost.protection,
      protection_at: ghost.protection_at
    }
    |> Protection.reinforce(state)
  end

  def delete(state, key) do
    %{
      state
      | t1: LRU.delete(state.t1, key),
        t2: LRU.delete(state.t2, key),
        b1: LRU.delete(state.b1, key),
        b2: LRU.delete(state.b2, key)
    }
  end

  defp adapt_weights(state, ghost, list) do
    latency =
      CostModel.normalise_latency(
        ghost.latency_us,
        state.latency_ref_us
      )

    memory =
      CostModel.normalise_memory(
        ghost.memory_bytes,
        state.memory_ref_bytes
      )

    delta = latency - memory

    weights =
      case list do
        :t1 -> state.w1
        :t2 -> state.w2
      end

    new_latency =
      (weights.latency + state.eta * delta)
      |> max(0.1)
      |> min(0.9)

    updated_weights = %{
      latency: new_latency,
      memory: 1.0 - new_latency
    }

    case list do
      :t1 -> %{state | w1: updated_weights}
      :t2 -> %{state | w2: updated_weights}
    end
  end

  defp adjust_parameter_up(state, b1, b2) do
    delta =
      max(
        div(LRU.size(b2), max(LRU.size(b1), 1)),
        1
      )

    %{state | p: min(state.capacity, state.p + delta)}
  end

  defp adjust_parameter_down(state, b1, b2) do
    delta =
      max(
        div(LRU.size(b1), max(LRU.size(b2), 1)),
        1
      )

    %{state | p: max(0, state.p - delta)}
  end

  defp replace(state, incoming_key) do
    t1_size = LRU.size(state.t1)

    evict_t1? =
      t1_size > 0 and
        (t1_size > state.p or (LRU.fetch(state.b2, incoming_key) != :miss and t1_size == state.p))

    if evict_t1? do
      {key, entry} = select_victim(state, state.t1, state.w1)

      ghost =
        %GGARC.GhostEntry{
          latency_us: entry.latency_us,
          memory_bytes: entry.memory_bytes,
          protection: entry.protection,
          protection_at: entry.protection_at
        }

      %{
        state
        | t1: LRU.delete(state.t1, key),
          b1: LRU.put(state.b1, key, ghost)
      }
    else
      if LRU.empty?(state.t2) do
        state
      else
        {key, entry} = select_victim(state, state.t2, state.w2)

        ghost =
          %GGARC.GhostEntry{
            latency_us: entry.latency_us,
            memory_bytes: entry.memory_bytes,
            protection: entry.protection,
            protection_at: entry.protection_at
          }

        %{
          state
          | t2: LRU.delete(state.t2, key),
            b2: LRU.put(state.t2, key, ghost)
        }
      end
    end
  end

  defp select_victim(state, list, weights) do
    list
    |> LRU.entries()
    |> Enum.min_by(fn {_key, entry} ->
      protection =
        GGARC.Protection.effective(
          entry,
          state.request_count,
          state.protection_half_life
        )

      GGARC.CostModel.score(entry, weights, state, protection)
    end)
  end

  defp insert_new(state, key, value, latency, memory) do
    c = state.capacity
    l1_size = LRU.size(state.t1) + LRU.size(state.b1)

    total_size =
      LRU.size(state.t1) + LRU.size(t2) + LRU.size(b1) + LRU.size(b2)

    state =
      cond do
        l1_size == c ->
          if LRU.size(state.t1) < c do
            {{_key, _value}, b1} = LRU.pop_lru(state.b1)

            %{state | b1: b1}
          else
            {{_key, _value}, t1} = LRU.pop_lru(state.t1)

            %{state | t1: t1}
          end

        l1_size < c and total_size >= c ->
          state =
            if total_size == 2 * c do
              {{_key, _value}, b2} = LRU.pop_lru(state.b2)
              %{state | b2: b2}
            else
              state
            end

          replace(state, key)

        true ->
          state
      end

    entry = %Entry{
      value: value,
      latency_us: latency,
      memory_bytes: memory,
      protection: 0.0,
      protection_at: state.request_count
    }

    %{state | t1: LRU.put(state.t1, key, entry)}
  end

  def stats(state) do
    %{
      capacity: state.capacity,
      p: state.p,
      t1: LRU.size(state.t1),
      t2: LRU.size(state.t2),
      b1: LRU.size(state.b1),
      b2: LRU.size(state.b2),
      resident: LRU.size(state.t1) + LRU.size(state.t2)
    }
  end
end
