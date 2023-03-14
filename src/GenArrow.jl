module GenArrow
using Gen
import Serialization
using Logging

RECORD_INFO = NamedTuple{(:record_ptr, :record_size, :is_trace), Tuple{Int64, Int64, Bool}}
LAZY_TYPE = Union{Gen.ChoiceOrCallRecord, RECORD_INFO}

include("ptrie.jl")
include("lazy/lazy.jl")
include("serialization/serialization.jl")
end