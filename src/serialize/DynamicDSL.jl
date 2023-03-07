import .Serialization
using Gen

function serialize_trie(io, trie::Trie{K,V}) where {K,V}
    write(io, length(trie.leaf_nodes))
    for (key, record) in trie.leaf_nodes
        # println(key, " ", record)
        Serialization.serialize(io, key)
        is_trace = isa(record.subtrace_or_retval, Trace)
        write(io, is_trace)

        if is_trace
            tr = record.subtrace_or_retval
            Serialization.serialize(io, typeof(tr))
            # println("Found trace")
            serialize(io, tr)
        else
            # TODO: De-swizzle record
            Serialization.serialize(io, record)
        end
    end

    write(io, length(trie.internal_nodes))
    # println("Internal nodes")
    for (key, subtrie) in trie.internal_nodes
        # println("Key: ", key, " subtrie: ", subtrie)
        Serialization.serialize(io, key)
        serialize_trie(io, subtrie)
    end
end

function serialize(io, tr::Gen.DynamicDSLTrace{T}) where {T} 
    # HEADER 
    # isempty, score, noise, args, retval, [trie]
    # [trie] is present if isempty is false
    
    Serialization.serialize(io, typeof(tr))
    # Serialization.serialize(io, tr.trie) # Not clear how to remove this
    write(io, tr.isempty)
    write(io, tr.score)
    write(io, tr.noise)
    # println("SERIALIZATION")
    # println("trie: ", tr.trie)
    # println("isempty: ", tr.isempty)
    # println("score: ", tr.score)
    # println("noise: ", tr.noise)
    # println("args: ", tr.args)
    # println("retval: ", tr.retval)
    # println("END")
    Serialization.serialize(io, tr.args)
    Serialization.serialize(io, tr.retval)
    if !tr.isempty
        serialize_trie(io, tr.trie)
    end
end

function deserialize_trie(gen_fn, io)
    leaf_count = read(io, Int64)
    # println("leaf count: ", leaf_count)
    # Leaf nodes
    trie = Trie{Any, Gen.ChoiceOrCallRecord}()
    for i=1:leaf_count
        key = Serialization.deserialize(io)
        is_trace = read(io, Bool)
        # println("Key: ", key)
        # println("is trace: ", is_trace)
        record = nothing
        if is_trace
            type = Serialization.deserialize(io)
            GenArrow.deserialize(gen_fn, io, type)
        else
            record = Serialization.deserialize(io)
        end
        trie.leaf_nodes[key] = record
    end

    # Internal nodes
    internal_count = read(io, Int64)
    # println("Deserialize Internal Nodes: ", internal_count)
    for i=1:internal_count
        key = Serialization.deserialize(io)
        subtrie = deserialize_trie(gen_fn, io)
        trie.internal_nodes[key] = subtrie
        # How to map this subtrie into key
    end
    return trie
end

function deserialize(gen_fn, io, ::Type{Gen.DynamicDSLTrace{U}}) where {U}
    isempty = read(io, Bool)
    score = read(io, Float64)
    noise = read(io, Float64)
    args = Serialization.deserialize(io)
    retval = Serialization.deserialize(io)
    # println("Deserialize")
    # println("isempty: ", isempty)
    # println("score: ", score)
    # println("noise: ", noise)
    # println("args: ", args)
    # println("retval: ", retval)

    trie = deserialize_trie(gen_fn, io)

    tr = Gen.DynamicDSLTrace{typeof(gen_fn)}(gen_fn, args)
    tr.trie = trie
    tr.isempty = isempty
    tr.score = score
    tr.noise = noise
    tr.retval = retval
    return tr
end

function deserialize(gen_fn, io)
    trace_type = Serialization.deserialize(io)
    GenArrow.deserialize(gen_fn, io, trace_type)
end