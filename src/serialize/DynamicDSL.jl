import .Serialization


# HEADER
# [attributes] [# of leaf] [is_leaf, size, address, non-trace] [internal, size, address, non-trace] [# internal] [is_leaf, address, trace] [internal, addres, trace]

function serialize_address_map(io, trie::Trie{K,V}) where {K,V}

    map = Dict{Any, Int64}()

    # Leaf address map
    leaf_map_ptr = io.ptr
    write(io, length(trie.leaf_nodes))
    for (addr, record) in trie.leaf_nodes
        # println(addr, " ", record)
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
        # println("Addr: ", addr)
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
        # println(addr, " ", record)
        is_trace = isa(record.subtrace_or_retval, Trace)
        ptr = io.ptr
        hmac = rand(1:100000)
        @debug "LEAF" addr is_trace record_in_map=map[addr] record _module="" hmac

        if is_trace
            tr = record.subtrace_or_retval
            serialize(io, tr)
        else
            # TODO: De-swizzle record
            Serialization.serialize(io, record)
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
