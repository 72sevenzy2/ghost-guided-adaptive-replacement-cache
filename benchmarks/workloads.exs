defmodule Workloads do
  @request_count 100_000

  def generate(type, opts \\ []) do
    seed = Keyword.get(opts, :seed, 42)
    count = Keyword.get(opts, :count, @request_count)
    capacity = Keyword.get(opts, :capacity, 1_000)

    :rand.seed(:exsss, {seed, seed + 1, seed + 2})

    backing_store = build_store(type, capacity)
    requests = build_requests(type, count, capacity)

    {requests, backing_store}
  end

  # A: Frequently accessed objects are expensive to retrieve.
  defp build_store(:expensive_hot, capacity) do
    for key <- 1..(capacity * 10), into: %{} do
      hot? = key <= capacity

      {key,
       %{
         value: "value_#{key}",
         latency_us: if(hot?, do: 50_000, else: 100),
         memory_bytes: 1_024
       }}
    end
  end

  # B: Objects have heterogeneous memory footprints.
  defp build_store(:heterogeneous_size, capacity) do
    for key <- 1..(capacity * 10), into: %{} do
      {key,
       %{
         value: "value_#{key}",
         latency_us: 10_000,
         memory_bytes: if(rem(key, 10) == 0, do: 65_536, else: 512)
       }}
    end
  end

  # C: Expensive objects are less frequently accessed.
  defp build_store(:frequency_cost_conflict, capacity) do
    for key <- 1..(capacity * 10), into: %{} do
      expensive? = key > capacity

      {key,
       %{
         value: "value_#{key}",
         latency_us: if(expensive?, do: 100_000, else: 100),
         memory_bytes: 1_024
       }}
    end
  end

  # D: Both latency and memory vary.
  defp build_store(:mixed_cost, capacity) do
    for key <- 1..(capacity * 10), into: %{} do
      {key,
       %{
         value: "value_#{key}",
         latency_us: 100 + rem(key * 7919, 50_000),
         memory_bytes: 512 + rem(key * 3571, 65_536)
       }}
    end
  end

  # E: The hot working set changes halfway through.
  defp build_store(:phase_shift, capacity) do
    for key <- 1..(capacity * 10), into: %{} do
      {key,
       %{
         value: "value_#{key}",
         latency_us: if(key > capacity * 5, do: 50_000, else: 100),
         memory_bytes: 1_024
       }}
    end
  end

  defp build_requests(:expensive_hot, count, capacity) do
    generate_requests(count, fn ->
      if :rand.uniform() <= 0.8 do
        :rand.uniform(capacity)
      else
        capacity + :rand.uniform(capacity * 9)
      end
    end)
  end

  defp build_requests(:heterogeneous_size, count, capacity) do
    generate_requests(count, fn ->
      :rand.uniform(capacity * 10)
    end)
  end

  defp build_requests(:frequency_cost_conflict, count, capacity) do
    generate_requests(count, fn ->
      if :rand.uniform() <= 0.9 do
        :rand.uniform(capacity)
      else
        capacity + :rand.uniform(capacity * 9)
      end
    end)
  end

  defp build_requests(:mixed_cost, count, capacity) do
    generate_requests(count, fn ->
      :rand.uniform(capacity * 10)
    end)
  end

  defp build_requests(:phase_shift, count, capacity) do
    half = div(count, 2)

    first =
      generate_requests(half, fn ->
        :rand.uniform(capacity)
      end)

    second =
      generate_requests(count - half, fn ->
        capacity * 5 + :rand.uniform(capacity)
      end)

    first ++ second
  end

  defp generate_requests(count, generator) do
    for _ <- 1..count, do: generator.()
  end
end
