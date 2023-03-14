module GenArrow
using Gen
import Serialization
using Logging

RECORD_TYPE = NamedTuple{(:record_ptr, :record_size, :is_trace), Tuple{Int64, Int64, Bool}}

include("ptrie.jl")
include("lazy/lazy.jl")
include("serialization/serialization.jl")
end