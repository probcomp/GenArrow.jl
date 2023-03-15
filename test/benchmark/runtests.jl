using Gen
using GenArrow: serialize, _deserialize, _deserialize_lazy

using ProfileView: view
using Profile
using BenchmarkTools
using Plots
using Test

include("models.jl")
include("tools.jl")

# bench, prof = serialize_benchmark(wide, (10000,))
# display(bench)
# view(prof)
# bench, prof = deserialize_benchmark(wide, (10000,))
# # bench, prof = deserialize_benchmark(heavy_choice, (1000,))
# display(bench)
# view(prof)
# bench, prof = lazy_deserialize_benchmark(wide, (10000,))
# # bench, prof = deserialize_benchmark(heavy_choice, (1000,))
# display(bench)
# view(prof)
bench, prof = deserialize_benchmark(stalling, (100000,))
display(bench)
view(prof)
bench, prof = lazy_deserialize_benchmark(stalling, (100000,))
display(bench)
view(prof)