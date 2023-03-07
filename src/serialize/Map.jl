using FunctionalCollections

function serialize(tr::Gen.VectorTrace{Gen.MapType, U, V}) where {U,V}
    io = IOBuffer()
    # HEADER
    # args, retvals, subtrace_count, len, num_nonempty, score, noise

    map_type = typeof(tr)
    Serialization.serialize(io, map_type)
    Serialization.serialize(io, tr.args)
    Serialization.serialize(io, tr.retval)
    write(io, length(tr.subtraces))
    write(io, tr.len)
    write(io, tr.num_nonempty)
    write(io, tr.score)
    write(io, tr.noise)
    # println("SERIALIZE VECTOR TRACE")
    # println("args: ", tr.args)
    # println("retval: ", tr.retval)
    # println("subtraces len: ", length(tr.subtraces))
    # println("len: ", tr.len)
    # println("num_nonempty: ", tr.num_nonempty)
    # println("score: ", tr.score)
    # println("noise: ", tr.noise)
    # println("END")

    for subtrace in tr.subtraces # TODO: Figure out if append type before helps
        GenArrow.serialize(io, subtrace)
    end
    return io
end

function deserialize(gen_fn, io, maptype::Type{Gen.VectorTrace{Gen.MapType, U, V}}) where {U, V}
    args = Serialization.deserialize(io)
    retval = Serialization.deserialize(io)
    subtraces_count = read(io, Int)
    len = read(io, Int)
    num_nonempty = read(io, Int)
    score = read(io, Float64)
    noise = read(io, Float64)
    # println("DESERIALIZE VECTOR TRACE")
    # println("args: ", args)
    # println("retval: ", retval)
    # println("subtraces len: ", subtraces_count)
    # println("len: ", len)
    # println("num_nonempty: ", num_nonempty)
    # println("score: ", score)
    # println("noise: ", noise)
    # println("END")
    
    subtraces = PersistentVector{Gen.DynamicDSLTrace}() # Optimize type inference
    # println(subtraces_count, " ", retval_count, " ", len, " ", num_nonempty, " ", noise)
    for i=1:subtraces_count
        type = Serialization.deserialize(io)
        # println("Deserialize type: ", type)
        tr = GenArrow.deserialize(gen_fn.kernel, io, type)
        subtraces = push(subtraces, tr)
    end
    maptype(gen_fn, subtraces, retval, args, score, noise, len, num_nonempty)
end
