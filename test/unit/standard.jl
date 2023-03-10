using Serialization
# @gen function model()
#     x ~ mvnormal([0, 0], [1 0; 0 1])
#     if (b ~ bernoulli(0.5))
#         y ~ categorical([0.25, 0.25, 0.25, 0.25])
#         {:a => 1} ~ bernoulli(0.5)
#     else
#         z ~ exponential(2)
#         {:c => 1} ~ bernoulli(0.5)
#     end
# end

@gen function model(n)
    x ~ bernoulli(0.5)
    y ~ submodel(n)
end
@gen function submodel(n)
    for i=1:n
        @trace(normal(0.0, 1), i)
    end
end
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
end

function test_leaves()
    io = IOBuffer()
    tr, weight = generate(model, (10,)) 
    io = GenArrow.serialize(tr)

    seekstart(io)
    tr_deserialized = GenArrow._deserialize(model, io)
    basic_equality(tr, tr_deserialized)
    return true
end

function test_internal()
end