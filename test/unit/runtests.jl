using Gen
using GenArrow
using Arrow
using FilePathsBase
using Test

include("standard.jl")
include("models.jl")

@test test_leaves()
@test test_internal()
@test test_mixed()
@test (@untraced test_dist_with_untraced_arg 100)()
@test (@untraced test_subtrace_with_untraced_arg 100)()
@test (@untraced test_untraced_mixed 100)()
