results, profs = benchmark_write_batch("gen_1", gen_1, exp_scale(1000000, 1, 1), args_generator)
BenchmarkTools.save("test/timings.json", results)

ProfileView.view(profs[1000000])

# display(results["20"])
# plot_benchmark("test/timings.json")
