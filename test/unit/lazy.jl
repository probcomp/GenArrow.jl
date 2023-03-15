function test_lazy_basic()
    io = IOBuffer()
    tr, weight = generate(basic, (4,)) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize_lazy(io)
    observational_equality(tr, tr_deserialized)
end

function test_lazy_leaves()
    io = IOBuffer()
    tr, weight = generate(leaves, (4,)) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize_lazy(io)
    observational_equality(tr, tr_deserialized)
end

function test_lazy_internal()
    io = IOBuffer()
    tr, weight = generate(internal, (4,)) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize_lazy(io)
    observational_equality(tr, tr_deserialized)
end

function test_lazy_mixed()
    io = IOBuffer()
    tr, weight = generate(mixed, (2,)) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize_lazy(io)
    observational_equality(tr, tr_deserialized)
end

function test_lazy_dist_with_untraced_arg()
    io = IOBuffer()
    tr, weight = generate(dist_with_untraced_arg, ()) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize_lazy(io)
    observational_equality(tr, tr_deserialized)
end

function test_lazy_subtrace_with_untraced_arg()
    io = IOBuffer()
    tr, weight = generate(subtrace_with_untraced_arg, ()) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize_lazy(io)
    observational_equality(tr, tr_deserialized)
end

function test_lazy_untraced_mixed()
    io = IOBuffer()
    tr, weight = generate(untraced_mixed, (10,)) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize_lazy(io)
    observational_equality(tr, tr_deserialized)
end

