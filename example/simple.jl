module Simple

using Arrow
using Gen
using GenArrow
using LinearAlgebra

@gen function submodel()
    for k in 1:100
        {:y => k => k} ~ normal(0.0, 1.0)
    end
end

@gen function model()
    for k in 1:1000
        {:x => k => k} ~ mvnormal(zeros(100), I(100))
    end
    q ~ submodel()
end

activate("sample") do ctx
    tr = simulate(model, ())
    GenArrow.write!(ctx, tr)
    tr = simulate(model, ())
    GenArrow.write!(ctx, tr)
    tr = simulate(model, ())
    GenArrow.write!(ctx, tr)
    tr = simulate(model, ())
    GenArrow.write!(ctx, tr)
end

end # module
