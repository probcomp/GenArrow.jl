function test_leaves()
    io = IOBuffer()
    tr, weight = generate(leaves, (10,)) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize(leaves, io)
    observational_equality(tr, tr_deserialized)
end

function test_internal()
    io = IOBuffer()
    tr, weight = generate(internal, (10,)) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize(internal, io)
    observational_equality(tr, tr_deserialized)
end

function test_mixed()
    io = IOBuffer()
    tr, weight = generate(mixed, (2,)) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize(mixed, io)
    observational_equality(tr, tr_deserialized)
end

function test_dist_with_untraced_arg()
    io = IOBuffer()
    tr, weight = generate(dist_with_untraced_arg, ()) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize(dist_with_untraced_arg, io)
    observational_equality(tr, tr_deserialized)
end

function test_subtrace_with_untraced_arg()
    io = IOBuffer()
    tr, weight = generate(subtrace_with_untraced_arg, ()) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize(subtrace_with_untraced_arg, io)
    observational_equality(tr, tr_deserialized)
end

function test_untraced_mixed()
    io = IOBuffer()
    tr, weight = generate(untraced_mixed, (10,)) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize(untraced_mixed, io)
    observational_equality(tr, tr_deserialized)
end

