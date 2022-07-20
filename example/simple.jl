module Simple

using Arrow
using Gen
using GenArrow

@gen function model()
    x ~ normal(0.0, 1.0)
    return x
end

tr = simulate(model, ())
Arrow.write("some_file.arrow", tr)
tbl = Arrow.Table(Arrow.read("some_file.arrow"))
@info tbl

end # module
