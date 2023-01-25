using Plots

function plot_benchmark(fname::String)
  results = BenchmarkTools.load(fname)
  for n in results
    println("Woah")
  end
end


