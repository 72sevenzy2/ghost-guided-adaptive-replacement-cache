Code.require_file("workloads.exs", __DIR__)
Code.require_file("arc_runner.ex", __DIR__)
Code.require_file("ggarc_runner.ex", __DIR__)

capacity = 1_000

workloads = [
  :expensive_hot,
  :heterogeneous_size,
  :frequency_cost_conflict,
  :mixed_cost,
  :phase_shift
]

for workload <- workloads do
  IO.puts("\n========== #{workload} ==========")

  for seed <- 1..10 do
    {requests, backing_store} =
      Workloads.generate(workload, capacity: capacity, seed: seed)

    arc = ARCRunner.run(requests, backing_store, capacity)
    ggarc = GGARCRunner.run(requests, backing_store, capacity)

    saved =
      arc.retrieval_cost_us - ggarc.retrieval_cost_us

    reduction =
      saved / arc.retrieval_cost_us * 100

    IO.inspect(%{
      seed: seed,
      arc_cost: arc.retrieval_cost_us,
      ggarc_cost: ggarc.retrieval_cost_us,
      cost_saved_us: saved,
      reduction_percent: Float.round(reduction, 3),
      arc_hits: arc.hits,
      ggarc_hits: ggarc.hits
    })
  end
end
