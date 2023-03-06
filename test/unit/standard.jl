using Serialization
@gen function model()
    x ~ mvnormal([0, 0], [1 0; 0 1])
    if (b ~ bernoulli(0.5))
        y ~ categorical([0.25, 0.25, 0.25, 0.25])
        {:a => 1} ~ bernoulli(0.5)
    else
        z ~ exponential(2)
        {:c => 1} ~ bernoulli(0.5)
    end
end

function test_1()
    tr_old, w_old = generate(model, ())
    activate(Path("./test/unit/dump")) do ctx
        handler = GenArrow.create_handler!(ctx, "dump")
        write!(handler, tr_old, "test_1")
    end
    tr_new, w_new = GenArrow.deserialize(model, "./test/unit/dump/dump/test_1")
    if (get_choices(tr_old) != get_choices(tr_new))
        display(get_choices(tr_old))
        display(get_choices(tr_new))
    end
    if (get_score(tr_old) != get_score(tr_new))
        throw()
    end
    if (get_args(tr_old) != get_args(tr_new))
        throw()
    end
    if (get_retval(tr_old) != get_retval(tr_old))
        throw()
    end
end

# function test_2()
#     tr_old, w_old = generate(model, ())
#     GenArrow.save("./test/unit/dump/what", tr_old)
# end
# test_2()
