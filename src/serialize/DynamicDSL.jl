import .Serialization

function serialize(io, tr::Gen.DynamicDSLTrace) 
    # HEADER trie, isempty, score, noise, args, retval
    
    # TODO: Determine length by getting ptr diff
    Serialization.serialize(io, typeof(tr))
    Serialization.serialize(io, tr.trie) # Not clear how to remove this
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
end

function deserialize(gen_fn, io, ::Type{Gen.DynamicDSLTrace{U}}) where {U}
    trie = Serialization.deserialize(io)
    isempty = read(io, Bool)
    score = read(io, Float64)
    noise = read(io, Float64)
    args = Serialization.deserialize(io)
    retval = Serialization.deserialize(io)
    # println("Deserialize DSL ", trie, "\n", isempty, " ", score, " ", noise)
    # println("args: $(args)")
    # println("retval: $(retval)")
    # How to reconstruct?
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