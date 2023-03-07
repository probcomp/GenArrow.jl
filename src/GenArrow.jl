module GenArrow
using Arrow
using ArrowTypes
using Gen
using Tables
using DataFrames
using FilePathsBase
using Serialization

include("GenTable.jl")
include("AddressTrie.jl")
include("ContextManager.jl")
include("Serialize.jl")
include("./serialize/DynamicDSL.jl")
include("./serialize/Map.jl")
end
