module GenArrow
using Arrow
using ArrowTypes
using Gen
using Tables
using DataFrames
using FilePathsBase
using Serialization
using Logging

include("GenTable.jl")
include("AddressTrie.jl")
include("ContextManager.jl")
include("Serialize.jl")
include("./serialize/DynamicDSL.jl")
include("./serialize/Map.jl")
include("./serialize/trie.jl")
include("./serialize/deserialize.jl")
end
