using Gen
using GenArrow
using Arrow
using FilePathsBase
using Test

include("standard.jl")
include("models.jl")
# include("trie.jl")



@test test_leaves()
@test test_internal()
@test test_mixed()