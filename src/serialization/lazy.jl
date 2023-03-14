mutable struct LazyDeserializeState
    trace::LazyTrace
    io::IO # Change to blob
    ptr_trie::PTrie{Any, LAZY_TYPE}
    visitor::Gen.AddressVisitor
    params::Dict{Symbol,Any}
end

function _deserialize_maps(io, ptr_trie::PTrie{Any, LAZY_TYPE}, prefix::Tuple)
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

        if !is_trace
            restore_ptr = io.ptr
            io.ptr = record_ptr
            score = read(io, Float64)
            noise = read(io, Float64)
            is_choice = read(io, Bool)
            subtrace_or_retval = Serialization.deserialize(io)
            record = Gen.ChoiceOrCallRecord(subtrace_or_retval, score, noise, is_choice)
            ptr_trie[addr] = record
            @debug "NON-SUBTRACE LEAF" score noise is_choice
            io.ptr = restore_ptr
        else
            ptr_trie[addr] = (record_ptr=record_ptr, record_size=record_size, is_trace=is_trace)
            @debug "SUBTRACE LEAF" subtrace_record=ptr_trie[addr]
        end

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

        set_internal_node!(ptr_trie, addr, trie_ptr, trie_size)

        restore_ptr = io.ptr
        io.ptr = trie_ptr # Next trie
        _deserialize_maps(io, ptr_trie, flattened_addr)
        io.ptr = restore_ptr
    end

    @debug "MAP" ptr_trie _module=""

    ptr_trie
end

function LazyDeserializeState(gen_fn, io, params)
    trace_type = Serialization.deserialize(io)
    isempty = read(io, Bool)
    score = read(io, Float64)
    noise = read(io, Float64)
    args = Serialization.deserialize(io)
    retval = Serialization.deserialize(io)

    @debug "DESERIALIZE" type=trace_type isempty score noise args retval gen_fn _module=""
    ptr_trie = PTrie{Any, LAZY_TYPE}(-1,-1)
    _deserialize_maps(io, ptr_trie, ())
    if isempty
        throw("Need to figure this out")
    else
        @debug "TODO: Non-empty?" _module=""
    end
    # display(ptr_trie)

    trace = LazyTrace(io, args) 
    trace.isempty = isempty
    trace.score = score # add_call! and add_choice! double count
    trace.noise = noise
    trace.retval = retval
    trace.trie = ptr_trie
    LazyDeserializeState(trace, io, ptr_trie, Gen.AddressVisitor(), params)
end

function _deserialize(gen_fn::Gen.DynamicDSLFunction, io::IO, lazy)
    state = LazyDeserializeState(gen_fn, io, gen_fn.params)
    Gen.set_retval!(state.trace, get_retval(state.trace))
    # @debug "END" tr=get_choices(state.trace)
    state.trace
end