# HEADER
# [attributes] [# of leaf] [is_leaf, size, address, non-trace] [internal, size, address, non-trace] [# internal] [is_leaf, address, trace] [internal, addres, trace]

function serialize_address_map(io, trie::Trie{K,V}) where {K,V}

    map = Dict{Any, Int64}()

    # Leaf address map
    leaf_map_ptr = io.ptr
    write(io, length(trie.leaf_nodes))
    for (addr, record) in trie.leaf_nodes
        is_trace = isa(record.subtrace_or_retval, Trace)
        Serialization.serialize(io, addr)
        map[addr] = io.ptr
        write(io, 0) # Record ptr
        write(io, 0) # Size of record
        write(io, is_trace)
    end

    internal_map_ptr = io.ptr
    write(io, length(trie.internal_nodes))
    for (addr, subtrie) in trie.internal_nodes
        Serialization.serialize(io, addr)

        # TODO: Add assertion here. If DynamicDSL invariant holds, then maybe not necessary?
        map[addr] = io.ptr
        write(io, 0) # Trie ptr 
        write(io,0) # Size of trie
    end
    @debug "MAP" map leaf_map_ptr internal_map_ptr _module=""
    map, leaf_map_ptr, internal_map_ptr
end

function serialize_records(io, trie::Trie{K,V}, map::Dict{Any, Int64}) where {K,V}
    # Choices/Traces
    for (addr, record) in trie.leaf_nodes
        is_trace = isa(record.subtrace_or_retval, Trace)
        ptr = io.ptr
        hmac = rand(1:100000)
        @debug "LEAF" addr is_trace record_in_map=map[addr] record _module="" hmac

        if is_trace
            tr = record.subtrace_or_retval
            serialize(io, tr)
        else
            # Deswizzle record
            write(io, record.score)
            write(io, record.noise)
            write(io, record.is_choice)
            Serialization.serialize(io, record.subtrace_or_retval)
        end

        # TODO: Check if nothing was serialized?
        io.ptr = map[addr]
        write(io, ptr)
        write(io, io.size - ptr)
        @debug "LEAF" addr record_ptr=ptr length=(io.size-ptr) hmac _module=""
        seekend(io)
    end

    for (addr, subtrie) in trie.internal_nodes
        hmac = rand(-10000:-1)
        ptr = io.ptr
        @debug "INTERNAL" addr hmac trie=ptr
        serialize_trie(io, subtrie)
        io.ptr = map[addr]
        write(io, ptr)
        write(io, io.size - ptr)
        seekend(io)
        @debug "INTERNAL" addr record_ptr=ptr length=(io.size-ptr) hmac=hmac _module=""
    end
end

function serialize_trie(io, trie::Trie{K,V}) where {K,V}
    # HEADER - | leaf count | leaf map | leaves | internal count | addr map | tries | 
    ptr = io.ptr
    write(io, 0) # ptr to leaf map
    write(io, 0) # ptr to internal map
    @debug "TRIE" start=ptr
    addr_map, leaf_map_ptr, internal_map_ptr = serialize_address_map(io, trie)
    @debug "MAP PTRS" leaf_map_ptr internal_map_ptr
    io.ptr = ptr
    write(io, leaf_map_ptr)
    write(io, internal_map_ptr)
    seekend(io)
    serialize_records(io, trie, addr_map)
end

function serialize(io, tr::Gen.DynamicDSLTrace{T}) where {T} 
    # HEADER - type, isempty, score, noise, args, retval, [trie]
    
    Serialization.serialize(io, typeof(tr))
    write(io, tr.isempty)
    write(io, tr.score)
    write(io, tr.noise)
    Serialization.serialize(io, tr.args)
    Serialization.serialize(io, tr.retval)
    @debug "HEADER" type=typeof(tr) tr.isempty tr.score tr.noise tr.args tr.retval _module=""

    if !tr.isempty
        serialize_trie(io, tr.trie)
    end

    @debug "END" _module=""
    return nothing
end

function serialize(tr::Gen.DynamicDSLTrace{T}) where {T}
    io = IOBuffer()
    serialize(io,tr)
    io
end

##################
# DESERIALIZATION
##################

mutable struct GFDeserializeState
    trace::Gen.DynamicDSLTrace
    io::IO # Change to blob
    ptr_trie::Gen.Trie{Any, RECORD_INFO}
    visitor::Gen.AddressVisitor
    params::Dict{Symbol,Any}
end

function _deserialize_maps(io, ptr_trie::Trie{Any, RECORD_INFO}, prefix::Tuple)

    current_trie = io.ptr
    leaf_map_ptr = read(io, Int)
    internal_map_ptr = read(io, Int)
    @debug "[LEAF MAP] [INTERNAL MAP PTR]" current_trie leaf_map_ptr internal_map_ptr
    leaf_count = read(io, Int)
    @debug "LEAF COUNT" leaf_count
    for i=1:leaf_count
        addr = foldr(=> , (prefix..., Serialization.deserialize(io)))
        record_ptr = read(io, Int)
        record_size = read(io, Int)
        is_trace = read(io, Bool)

        ptr_trie[addr] = (record_ptr=record_ptr, record_size=record_size, is_trace=is_trace)
        @debug "LEAF" addr record_ptr size=record_size is_trace
    end

    internal_count = read(io, Int)
    @debug "INTERNAL COUNT" internal_count
    for i=1:internal_count
        flattened_addr = (prefix..., Serialization.deserialize(io))
        addr = foldr(=> , flattened_addr)
        trie_ptr = read(io, Int)
        trie_size = read(io,Int)
        @debug "INTERNAL" addr trie_ptr trie_size  

        internal_node = Gen.Trie{Any, RECORD_INFO}()
        Gen.set_internal_node!(ptr_trie, addr, internal_node)

        restore_ptr = io.ptr
        io.ptr = trie_ptr # Next trie
        _deserialize_maps(io, ptr_trie, flattened_addr)
        io.ptr = restore_ptr
    end

    @debug "MAP" ptr_trie _module=""

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
    ptr_trie = Gen.Trie{Any, RECORD_INFO}()
    _deserialize_maps(io, ptr_trie, ())
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

    if haskey(state.ptr_trie, key)
        ptr, size ,is_trace = state.ptr_trie[key]
        state.io.ptr = ptr
        score = read(state.io, Float64)
        noise = read(state.io, Float64)
        is_choice = read(state.io, Bool)
        subtrace_or_retval = Serialization.deserialize(state.io)
        record = Gen.ChoiceOrCallRecord(subtrace_or_retval, score, noise, is_choice)
        @debug "CHOICE" ptr size is_trace record
    else
        @warn "LOST KEY" key state.ptr_trie _module=""
        throw("$(key) Key not in leaf or internal maps")
    end


    retval = record.subtrace_or_retval
    # Check if it is truly a retval

    # constrained = has_value(state.constraints, key)
    # !constrained && check_no_submap(state.constraints, key)

    # intercept logpdf
    score = record.score
    @debug "TRACEAT DIST" key record score retval args dist

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
    if haskey(state.ptr_trie, key)
        ptr, size ,is_trace = state.ptr_trie[key]
        state.io.ptr = ptr
        @debug "SUBTRACE" ptr size is_trace
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

function _deserialize(gen_fn::Gen.DynamicDSLFunction, io::IO)
    state = GFDeserializeState(gen_fn, io, gen_fn.params)
    # Deserialize stuff including args and retval
    _ = Gen.exec(gen_fn, state, state.trace.args)
    Gen.set_retval!(state.trace, Gen.get_retval(state.trace))
    @debug "END" tr=get_choices(state.trace)
    state.trace
end
