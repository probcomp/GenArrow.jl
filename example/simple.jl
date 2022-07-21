module Simple

using Arrow
using Gen
using GenArrow

@gen function submodel()
    for k in 1:100000
        {:y => k} ~ normal(0.0, 1.0)
    end
end

@gen function model()
    for k in 1:100000
        {:x => k} ~ normal(0.0, 1.0)
    end
    q ~ submodel()
end

tr = simulate(model, ())
metadata, sparse_choices = GenArrow.traverse(tr)
GenArrow.serialize("sample/", tr)

end # module
