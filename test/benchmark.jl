using BenchmarkTools
using GenArrow
using FilePathsBase
using Gen
using ProfileView
using Profile
include("generative_examples.jl")

function exp_scale(start, phi, N)
  [ceil(Int64, start * (phi^i)) for i in 1:N]
end

function generate_batch(gen_fn, args_iter)
  traces = Gen.Trace[]
  for args in args_iter
    push!(traces, simulate(gen_fn, args))
  end
  return traces
end

function benchmark_batch(benchmark_name, gen_fn, scale_iter, args_generator)
  results = BenchmarkGroup()
  prof_results = []
  for n in scale_iter
    traces = generate_batch(gen_fn, args_generator(n))
    Profile.clear()
    activate(Path("./test/arrow")) do ctx
      handler = GenArrow.create_handler!(ctx, benchmark_name)
      name = "$n"
      bench = @bprofile write!($handler, $traces, $name)
      prof = Profile.fetch()
      results["$n"] = bench
      push!(prof_results, prof)
    end
  end
  return results, prof_results
end

function args_generator(N)
  Channel() do channel
    push!(channel, (1,))
  end
end
results, profs = benchmark_batch("gen_1", gen_1, exp_scale(10, 2, 2), args_generator)

