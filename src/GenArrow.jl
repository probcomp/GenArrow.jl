module GenArrow
using Gen
import Serialization
using Logging

include("ptrie.jl")
include("lazy/lazy.jl")
include("serialization/serialization.jl")
end