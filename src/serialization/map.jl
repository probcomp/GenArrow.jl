using FunctionalCollections

function serialize(io::IO, tr::Gen.VectorTrace{Gen.MapType, U, V}) where {U,V}
    # HEADER args, retvals, subtrace_count, len, num_nonempty, score, noise

    map_type = typeof(tr)
    Serialization.serialize(io, map_type)
    Serialization.serialize(io, tr.args)
    Serialization.serialize(io, tr.retval)
    write(io, length(tr.subtraces))
    write(io, tr.len)
    write(io, tr.num_nonempty)
    write(io, tr.score)
    write(io, tr.noise)
    @debug "VECTOR" map_type args=tr.args retval=tr.retval length_subtraces=length(tr.subtraces) len=tr.len score=tr.score noise=tr.noise

    for subtrace in tr.subtraces # TODO: Figure out if append type before helps
        Serialization.serialize(io, typeof(subtrace))
    end
    for subtrace in tr.subtraces
        GenArrow.serialize(io, subtrace)
    end
end

function serialize(tr::Gen.VectorTrace{Gen.MapType, U, V}) where {U,V}
    io = IOBuffer()
    serialize(io, tr)
    io
end


#################
# DESERIALIZATION
#################

# RECORD_TYPE = NamedTuple{(:record_ptr, :record_size, :is_trace), Tuple{Int64, Int64, Int64}}
mutable struct MapDeserializeState{T,U}
    score::Float64
    noise::Float64
    weight::Float64
    subtraces::Vector{U}
    retval::Vector{T}
    num_nonempty::Int
end

function process!(gen_fn::Map{T,U}, args::Tuple, io::IO, key::Int, state::MapDeserializeState{T,U}) where {T,U}
    local subtrace::U
    local retval::T

    subtrace = _deserialize(gen_fn.kernel, io)
    
    state.noise += project(subtrace, EmptySelection())
    state.num_nonempty += (isempty(get_choices(subtrace)) ? 0 : 1)
    state.score += get_score(subtrace)
    state.subtraces[key] = subtrace
    retval = get_retval(subtrace)
    state.retval[key] = retval
    @debug "VECTOR PROCESS" key subtrace _module=""

end

function _deserialize(gen_fn::Gen.Map{T,U}, io::IO) where {T,U}
    trace_type = Serialization.deserialize(io)
    args = Serialization.deserialize(io)
    retval = Serialization.deserialize(io)
    subtrace_count = read(io, Int64)
    len = read(io, Int64)
    num_nonempty = read(io, Int64)
    score = read(io, Float64)
    noise = read(io, Float64)

    state = MapDeserializeState{T,U}(0., 0., 0., Vector{U}(undef, len), Vector{T}(undef, len), 0)

    @debug "VECTOR DESERIALIZE" type=trace_type isempty score noise count = subtrace_count len num_nonempty args retval gen_fn state _module=""

    trace_types = []
    for key=1:length(args[1])
        push!(trace_types, Serialization.deserialize(io))
    end

    @debug "Vector ELTYPE" subtrace_count trace_types _module=""

    for key=1:length(args[1])
        process!(gen_fn, args, io, key, state)
    end

    @debug "VECTOR END" state _module=""

    trace = Gen.VectorTrace{Gen.MapType, T, U}(gen_fn,
        PersistentVector{U}(state.subtraces), PersistentVector{T}(state.retval),
        args, state.score, state.noise, len, state.num_nonempty) # Optimize type inference
    @debug "MAP END" chm=get_choices(trace)
    trace
end