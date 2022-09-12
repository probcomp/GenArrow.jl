module GenArrowTour

# This file provides an introductory tour of GenArrow.jl by generating and storing traces from a space-intensive generative function.

using Arrow
using Gen
using GenArrow
using FilePathsBase
using LinearAlgebra

# Here, we define a model and a submodel.

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

# To create a `GenArrow.jl` managed directory, we pass a path into
# `activate`. `activate` returns a `ctx::SerializationContext` - 
# a management structure which provides interfaces to read/write serialized
# output.
activate(Path("./sample")) do ctx

    # Here, we sample a `tr::Gen.Trace` for our model.
    # Then, we save it to the serialization directory
    # with `GenArrow.write!`
    tr = simulate(model, ())
    GenArrow.write!(ctx, tr)
    # `GenArrow` keeps track of each trace using a UUID.

    # Multiple `write!` statements are perfectly acceptable.
    tr = simulate(model, ())
end

# Now, once we have a serialization directory, we may want to query it later,
# to perform analysis on the traces we sampled from our models or inference
# algorithms.

end # module
