import .Serialization
using Gen
using Logging


# HEADER
# [attributes] [# of leaf] [is_leaf, size, address, non-trace] [internal, size, address, non-trace] [# internal] [is_leaf, address, trace] [internal, addres, trace]

function serialize_address_map(io, trie::Trie{K,V}) where {K,V}
    # println("Leaf nodes: ", keys(trie.leaf_nodes))
    # println("Internal addr: ", keys(trie.internal_nodes))
    write(io, length(trie.leaf_nodes))

    map = Dict{Any, Int64}()

    # Leaf address map
    for (addr, record) in trie.leaf_nodes
        # println(addr, " ", record)
        is_trace = isa(record.subtrace_or_retval, Trace)
        Serialization.serialize(io, addr)
        map[addr] = io.ptr
        write(io, 0) # Record ptr
        write(io, 0) # Size of record
        write(io, is_trace)
    end

    write(io, length(trie.internal_nodes))
    for (addr, subtrie) in trie.internal_nodes
        # println("Addr: ", addr)
        Serialization.serialize(io, addr)

        # TODO: Add assertion here. If DynamicDSL invariant holds, then maybe not necessary?
        
        map[addr] = io.ptr
        write(io, 0) # Trie ptr 
        write(io,0) # Size of trie
    end
    @debug "MAP " map _module=""
    map
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
        @debug "INTERNAL" addr
        Serialization.serialize(io, addr)
        serialize_trie(io, subtrie)
    end
end

function serialize_trie(io, trie::Trie{K,V}) where {K,V}
    # HEADER - | leaf count | leaf map | leaves | internal count | addr map | tries | 
    addr_map = serialize_address_map(io, trie)
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
# macro serialize_with_io(tr_type)
#     println(typeof(tr_type), " ", tr_type)
#     quote
#         function serialize(tr::$(tr_type))
#             println("Sup")
#         end 
#     end
# end

# @serialize_with_io(Gen.DynamicDSLTrace{T})
function serialize(tr::Gen.DynamicDSLTrace{T}) where {T}
    io = IOBuffer()
    serialize(io,tr)
    io
end

# end

# function deserialize_trie(io)
#     leaf_count = read(io, Int64)
#     println("leaf count: ", leaf_count)
#     # Leaf nodes
#     trie = Trie{Any, Gen.ChoiceOrCallRecord}()
#     for i=1:leaf_count
#         key = Serialization.deserialize(io)
#         is_trace = read(io, Bool)
#         # println("Key: ", key)
#         # println("is trace: ", is_trace)
#         record = nothing
#         if is_trace
#             type = Serialization.deserialize(io)
#             # println("Subtrace type: ", type)
#             GenArrow.deserialize(io, type)
#         else
#             record = Serialization.deserialize(io)
#         end
#         trie.leaf_nodes[key] = record
#     end

#     # Internal nodes
#     internal_count = read(io, Int64)
#     # println("Deserialize Internal Nodes: ", internal_count)
#     for i=1:internal_count
#         key = Serialization.deserialize(io)
#         subtrie = deserialize_trie(io)
#         trie.internal_nodes[key] = subtrie
#         # How to map this subtrie into key
#     end
#     return trie
# end

# function deserialize(io, ::Type{Gen.DynamicDSLTrace{U}}) where {U}
#     isempty = read(io, Bool)
#     score = read(io, Float64)
#     noise = read(io, Float64)
#     args = Serialization.deserialize(io)
#     retval = Serialization.deserialize(io)
#     println("Deserialize")
#     println("isempty: ", isempty)
#     println("score: ", score)
#     println("noise: ", noise)
#     println("args: ", args)
#     println("retval: ", retval)

#     trie = deserialize_trie(io)
#     println("END")

#     tr = Gen.DynamicDSLTrace{U}(gen_fn, args) # Problem because gen_fn is needed?
#     tr.trie = trie
#     tr.isempty = isempty
#     tr.score = score
#     tr.noise = noise
#     tr.retval = retval
#     return tr
# end

# function deserialize(io)
#     trace_type = Serialization.deserialize(io)
#     println("Trace type: ", trace_type)
#     GenArrow.deserialize(io, trace_type)
# end