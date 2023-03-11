using Serialization

function write_to_file(fname, input)
    seekstart(input)
    data = read(input, String)
    open(fname, "w") do io
        write(io, data)
    end
end

function basic_equality(tr1, tr2)
    if (get_choices(tr1) != get_choices(tr2))
        display(get_choices(tr1))
        display(get_choices(tr))
        return false
    end
    if (get_score(tr1) != get_score(tr2))
        throw()
        return false
    end
    if (get_args(tr1) != get_args(tr2))
        throw()
        return false
    end
    if (get_retval(tr1) != get_retval(tr2))
        throw()
        return false
    end
    return true
end

function test_leaves()
    io = IOBuffer()
    tr, weight = generate(leaves, (10,)) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize(leaves, io)
    basic_equality(tr, tr_deserialized)
end

function test_internal()
    io = IOBuffer()
    tr, weight = generate(internal, (10,)) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize(internal, io)
    basic_equality(tr, tr_deserialized)
end

function test_mixed()
    io = IOBuffer()
    tr, weight = generate(mixed, (2,)) 
    io = GenArrow.serialize(tr)
    seekstart(io)
    tr_deserialized = GenArrow._deserialize(mixed, io)
    basic_equality(tr, tr_deserialized)
end