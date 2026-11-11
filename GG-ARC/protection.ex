defmodule GGARC.Protection do
  alias GGARC.{Entry, State}

  def effective(%Entry{} = entry, request_count, half_life) do
    gamma = :math.pow(2, -1 / half_life)
    elapsed = request_count - entry.protection_at
    entry.protection * :math.pow(gamma, elapsed)
  end

  def reinforce(%Entry{} = entry, %State{} = state) do
    current =
      effective(
        entry,
        state.request_count,
        state.protection_half_life
      )

    %{
      entry
      | protection:
          min(
            state.protection_max,
            current + state.protection_delta
          ),
        protection_at: state.request_count
    }
  end
end
