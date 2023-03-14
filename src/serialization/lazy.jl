mutable struct LazyDeserializeState
    trace::LazyTrace
    io::IO # Change to blob
    visitor::Gen.AddressVisitor
end

function _deserialize_maps(trace::LazyTrace, io::IO,prefix::Tuple)
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

        restore_ptr = io.ptr
        if !is_trace
            io.ptr = record_ptr
            score = read(io, Float64)
            noise = read(io, Float64)
            is_choice = read(io, Bool)
            retval = Serialization.deserialize(io)
            Gen.add_choice!(trace, addr, retval, score)
            # ptr_trie[addr] = record
            @debug "NON-SUBTRACE LEAF" score noise is_choice
        else
            # Deserialize subtrace lazily
            io.ptr = record_ptr
            subtrace = _deserialize(io, true)
            Gen.add_call!(trace, addr, subtrace)
            @debug "SUBTRACE LEAF" subtrace=subtrace
            # trace.trie[addr] = (record_ptr=record_ptr, record_size=record_size, is_trace=is_trace)
        end
        io.ptr = restore_ptr

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

        Gen.set_internal_node!(trace.trie, addr)

        restore_ptr = io.ptr
        io.ptr = trie_ptr # Next trie
        _deserialize_maps(trace, io,flattened_addr)
        io.ptr = restore_ptr
    end

    @debug "MAP" trace.trie _module=""
    trace
end

function LazyDeserializeState(io)
    trace_type = Serialization.deserialize(io)
    isempty = read(io, Bool)
    score = read(io, Float64)
    noise = read(io, Float64)
    args = Serialization.deserialize(io)
    retval = Serialization.deserialize(io)

    @debug "DESERIALIZE" type=trace_type isempty score noise args retval _module=""
    trace = LazyTrace(args) 
    trace.isempty = isempty
    trace.score = score # add_call! and add_choice! double count
    trace.noise = noise
    trace.retval = retval
    trace.trie = Trie{Any, Gen.ChoiceOrCallRecord}()
    _deserialize_maps(trace, io, ())
    if isempty
        throw("Need to figure this out")
    else
        @debug "TODO: Non-empty?" _module=""
    end
    # display(ptr_trie)

    LazyDeserializeState(trace, io, Gen.AddressVisitor())
end

function _deserialize(io::IO, lazy)
    state = LazyDeserializeState(io)
    Gen.set_retval!(state.trace, get_retval(state.trace))
    @debug "END" tr=get_choices(state.trace)
    state.trace
end

function _deserialize(gen_fn, io::IO, lazy)
    trace = _deserialize(io, lazy)
    # convert top level to dynamic trace type
    convert_to_dynamic(gen_fn, trace)
end