import .Serialization

mutable struct GFDeserializeState
    trace::Gen.DynamicDSLTrace
    io::IOBuffer # Change to blob
    # leaf_map::Dict{Any, NamedTuple{(:record_ptr, :record_size, :is_trace), Tuple{Int64, Int64, Int64}}}
    # internal_map::Dict{Any,NamedTuple{(:ptr, :size), Tuple{Int64, Int64}}}
    ptr_trie::Ptrie{Any} # Need this to support internal nodes
    visitor::Gen.AddressVisitor
    params::Dict{Symbol,Any}
end

# assumes io is at position of the start of internal map
function _deserialize_internal_addresses(io, ptr_trie::Ptrie{Any}) 
    internal_count = read(io, Int)
    for i=1:internal_count
        addr = Serialization.deserialize(io)
        trie_ptr = read(io, Int)
        trie_size = read(io,Int)
        @debug "INTERNAL" addr trie_ptr trie_size  

        set_internal_node!(ptr_trie, addr, trie_ptr, trie_size)

        restore_ptr = io.ptr
        io.ptr = trie_ptr # Next trie
        next_leaf_map_ptr = read(io, Int)
        next_addr_map_ptr = read(io, Int)
        io.ptr = next_addr_map_ptr
        @debug "JUMP" trie_ptr next_leaf_map_ptr next_addr_map_ptr
        _deserialize_internal_addresses(io, ptr_trie)
        io.ptr = restore_ptr
    end
end

function _deserialize_maps(io)
    # leaf_map = Dict{Any, NamedTuple{(:record_ptr, :record_size, :is_trace), Tuple{Int64, Int64, Int64}}}()
    # internal_map = Dict{Any,NamedTuple{(:ptr, :size), Tuple{Int64, Int64}}}()
    ptr_trie = Ptrie{Any}(-1, -1)

    leaf_map_ptr = read(io, Int)
    internal_map_ptr = read(io, Int)
    @debug "[LEAF MAP] [INTERNAL MAP PTR]" leaf_map_ptr internal_map_ptr
    leaf_count = read(io, Int)
    for i=1:leaf_count
        addr = Serialization.deserialize(io)
        record_ptr = read(io, Int)
        record_size = read(io, Int)
        is_trace = read(io, Bool)
        # leaf_map[addr] = (record_ptr=record_ptr, record_size=record_size, is_trace=is_trace)
        set_leaf_node!(ptr_trie, addr, (record_ptr=record_ptr, record_size=record_size, is_trace=is_trace))
        @debug "LEAF" addr record_ptr size=record_size is_trace
    end

    _deserialize_internal_addresses(io, ptr_trie)
    @debug "MAP" ptr_trie.leaf_nodes ptr_trie.internal_nodes ptr_trie _module=""

    ptr_trie
end

function GFDeserializeState(gen_fn, io, params)
    trace_type = Serialization.deserialize(io)
    isempty = read(io, Bool)
    score = read(io, Float64)
    noise = read(io, Float64)
    args = Serialization.deserialize(io)
    retval = Serialization.deserialize(io)

    @debug "DESERIALIZE" type=trace_type isempty score noise args retval gen_fn _module=""
    ptr_trie = _deserialize_maps(io)
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
    GFDeserializeState(trace, io, ptr_trie, Gen.AddressVisitor(), params)
end

function Gen.traceat(state::GFDeserializeState, dist::Gen.Distribution{T}, args, key) where {T}
    local retval::T

    # check that key was not already visited, and mark it as visited
    Gen.visit!(state.visitor, key)

    # check if leaf_map or internal_map contains key

    if key in state.ptr_trie.leaf_nodes
        ptr, size ,is_trace = state.ptr_trie.leaf_nodes[key]
        state.io.ptr = ptr
        record = Serialization.deserialize(state.io)
        @debug "CHOICE" ptr size is_trace record
    elseif key in state.ptr_trie
        throw("Not implemented")
    else
        @warn "LOST KEY" key state.ptr_trie.leaf_nodes state.ptr_trie.internal_nodes _module=""
        throw("$(key) Key not in leaf or internal maps")
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

    if key in state.ptr_trie.leaf_nodes
        ptr, size ,is_trace = state.ptr_trie.leaf_nodes[key]
        state.io.ptr = ptr
        @debug "SUBTRACE" ptr size is_trace
    elseif key in state.ptr_trie
        throw("Not implemented")
    else
        @warn "LOST KEY" key state.ptr_trie.leaf_nodes state.internal_map _module=""
        throw("$(key) Key not in leaf or internal maps")
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
