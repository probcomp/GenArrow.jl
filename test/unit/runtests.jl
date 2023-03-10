using Gen
using GenArrow
using Arrow
using FilePathsBase
using Test

include("standard.jl")
include("trie.jl")



@test test_trie_1()
@test test_trie_2()
@test test_trie_3()