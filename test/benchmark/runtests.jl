using Gen
using GenArrow: serialize, _deserialize

using ProfileView: view
using Profile
using BenchmarkTools
using Plots
using Test

include("models.jl")
include("tools.jl")

# bench, prof = serialize_benchmark(wide, (10,))
bench, prof = deserialize_benchmark(wide, (1000,))
display(bench)
view(prof)