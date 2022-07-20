module Simple

using Arrow
using Gen
using GenArrow

@gen function model()
    for k in 1:1000
        {:x => k} ~ normal(0.0, 1.0)
    end
end

tr = simulate(model, ())
Arrow.write("some_file.arrow", tr)
partial_tr = GenArrow.deserialize("some_file.arrow")
@info partial_tr

end # module
