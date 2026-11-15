Code.require_file("arc_runner.ex", __DIR__)
Code.require_file("ggarc_runner.ex", __DIR__)

key_count = 10_000
request_count = 100_000
capacity = 1_000

:rand.seed(:exsss, {42, 43, 44})

keys = Enum.to_list(1..key_count)

requests =
  Enum.map(1..request_count, fn _ ->
    if :rand.uniform() < 0.8 do
      :rand.uniform(1_000)
    else
      :rand.uniform(key_count)
    end
  end)

backing_store =
  Map.new(keys, fn key ->
    {key,
     %{
       value: "value-#{key}",
       latency_us: 500 + rem(key * 7919, 20_000),
       memory_bytes: 256 + rem(key * 3571, 65_000)
     }}
  end)

arc_result = fn ->
  ARCRunner.run(requests, backing_store, capacity)
end

ggarc_result = fn ->
  GGARCRunner.run(requests, backing_store, capacity)
end

Benchee.run(
  %{
    "ARC" => arc_result,
    "GG-ARC" => ggarc_result
  },
  warmup: 3,
  time: 10,
  memory_time: 2
)

IO.puts("\n ARC results:")
IO.inspect(arc_result.(), pretty: true)

IO.puts("\n GGARC results:")
IO.inspect(ggarc_result.(), pretty: true)
