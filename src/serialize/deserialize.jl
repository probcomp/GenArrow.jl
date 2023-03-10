using Gen
import .Serialization
using Logging

mutable struct GFDeserializeState
    trace::Gen.DynamicDSLTrace
    io::IOBuffer # Change to blob
    leaf_map::Dict{Any, NamedTuple{(:record_ptr, :record_size, :is_trace), Tuple{Int64, Int64, Int64}}}
    internal_map::Dict{Any,NamedTuple{(:ptr, :size), Tuple{Int64, Int64}}}
    visitor::Gen.AddressVisitor
    params::Dict{Symbol,Any}
end

function _deserialize_maps(io)
    leaf_map = Dict{Any, NamedTuple{(:record_ptr, :record_size, :is_trace), Tuple{Int64, Int64, Int64}}}()
    internal_map = Dict{Any,NamedTuple{(:ptr, :size), Tuple{Int64, Int64}}}()
    leaf_count = read(io, Int)
    for i=1:leaf_count
        addr = Serialization.deserialize(io)
        record_ptr = read(io, Int)
        record_size = read(io, Int)
        is_trace = read(io, Bool)
        leaf_map[addr] = (record_ptr=record_ptr, record_size=record_size, is_trace=is_trace)
        @debug "LEAF" addr record_ptr size=record_size is_trace
    end

    internal_count = read(io, Int)
    for i=1:internal_count
        addr = Serialization.deserialize(io)
        trie_ptr = read(io, Int)
        trie_size = read(io,Int)
        internal_map[addr] = (ptr=trie_ptr, size=trie_size)
        @debug "INTERNAL" addr byte_size
    end
    @debug "MAP" leaf_map internal_map _module=""

    leaf_map, internal_map
end

function GFDeserializeState(gen_fn, io, params)
    trace_type = Serialization.deserialize(io)
    isempty = read(io, Bool)
    score = read(io, Float64)
    noise = read(io, Float64)
    args = Serialization.deserialize(io)
    retval = Serialization.deserialize(io)

    @debug "DESERIALIZE" type=trace_type isempty score noise args retval gen_fn _module=""
    leaf_map, internal_map = _deserialize_maps(io)
    if isempty
        throw("Need to figure this out")
    else
        @debug "TODO: Non-empty?" _module=""
    end

    # Populate trace with choices that are not subtraces_count
    # Populate state with to be determined subtrace addr => blanks

    trace = Gen.DynamicDSLTrace(gen_fn, args) 
    trace.isempty = isempty
    # trace.score = score # add_call! and add_choice! double count
    trace.noise = noise
    trace.retval = retval
    GFDeserializeState(trace, io, leaf_map, internal_map, Gen.AddressVisitor(), params)
end

function Gen.traceat(state::GFDeserializeState, dist::Gen.Distribution{T}, args, key) where {T}
    local retval::T

    # check that key was not already visited, and mark it as visited
    Gen.visit!(state.visitor, key)

    # check if leaf_map or internal_map contains key

    if key in keys(state.leaf_map)
        ptr, size ,is_trace = state.leaf_map[key]
        state.io.ptr = ptr
        record = Serialization.deserialize(state.io)
        @debug "CHOICE" ptr size is_trace record
    elseif key in keys(state.internal_map)
        throw("Not implemented")
    else
        throw("Key not in leaf or internal maps")
    end


    retval = record.subtrace_or_retval
    # Check if it is truly a retval

    # constrained = has_value(state.constraints, key)
    # !constrained && check_no_submap(state.constraints, key)

    # intercept logpdf
    score = record.score
    @debug "TRACEAT DIST" dist args key score retval

    # add to the trace
    Gen.add_choice!(state.trace, key, retval, score)

    # increment weight
    # if constrained
        # state.weight += score
    # end

    retval
end

function Gen.traceat(state::GFDeserializeState, gen_fn::Gen.GenerativeFunction{T,U},
              args, key) where {T,U}
    local subtrace::U
    local retval::T

    @debug "TRACEAT GENFUNC" gen_fn args key
    # check key was not already visited, and mark it as visited
    Gen.visit!(state.visitor, key)

    # check for constraints at this key

    if key in keys(state.leaf_map)
        ptr, size ,is_trace = state.leaf_map[key]
        state.io.ptr = ptr
        @debug "SUBTRACE" ptr size is_trace
    elseif key in keys(state.internal_map)
        throw("Not implemented")
    else
        throw("Key not in leaf or internal maps")
    end

    # get subtrace
    subtrace = _deserialize(gen_fn, state.io)

    # add to the trace
    Gen.add_call!(state.trace, key, subtrace)

    # update weight
    # state.weight += weight # TODO: What?

    # get return value
    retval = get_retval(subtrace) 

    retval
end

function Gen.splice(state::GFDeserializeState, gen_fn::Gen.DynamicDSLFunction,
                args::Tuple)
    println("Splice")
    prev_params = state.params
    state.params = gen_fn.params
    retval = Gen.exec(gen_fn, state, args)
    state.params = prev_params
    retval
end

function _deserialize(gen_fn::Gen.DynamicDSLFunction, io::IOBuffer)
    state = GFDeserializeState(gen_fn, io, gen_fn.params)
    # Deserialize stuff including args and retval
    retval = Gen.exec(gen_fn, state, state.trace.args)
    Gen.set_retval!(state.trace, retval)
    @debug "END" tr=get_choices(state.trace)
    state.trace
end