import Serialization

include("dynamic.jl")
include("map.jl")
include("unfold.jl")
include("lazy.jl")

function _deserialize_lazy(io::IO; gen_fn=nothing)
    restore_ptr = io.ptr
    trace_type = Serialization.deserialize(io)
    io.ptr = restore_ptr
    _deserialize_lazy(io, trace_type, gen_fn=gen_fn)
end

export _deserialize
export serialize
export _deserialize_lazy
