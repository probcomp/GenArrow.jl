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

# function test_1()
#     tr_old, w_old = generate(model, ())
#     activate(Path("./test/unit/dump")) do ctx
#         handler = GenArrow.create_handler!(ctx, "dump")
#         write!(handler, tr_old, "test_1")
#     end
#     tr_new, w_new = GenArrow.deserialize(model, "./test/unit/dump/dump/test_1")
#     if (get_choices(tr_old) != get_choices(tr_new))
#         display(get_choices(tr_old))
#         display(get_choices(tr_new))
#     end
#     if (get_score(tr_old) != get_score(tr_new))
#         throw()
#     end
#     if (get_args(tr_old) != get_args(tr_new))
#         throw()
#     end
#     if (get_retval(tr_old) != get_retval(tr_old))
#         throw()
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

function test_1()
    io = IOBuffer()
    tr, weight = generate(model, (10,)) 
    io = GenArrow.serialize(tr)

    seekstart(io)
    tr_new = GenArrow._deserialize(model, io)

    if (get_choices(tr_new) != get_choices(tr))
        display(get_choices(tr_new))
        display(get_choices(tr))
        return false
    end
    if (get_score(tr) != get_score(tr_new))
        throw()
        return false
    end
    if (get_args(tr) != get_args(tr_new))
        throw()
        return false
    end
    if (get_retval(tr) != get_retval(tr_new))
        throw()
        return false
    end

    return true
end