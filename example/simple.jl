module GenArrowTour

# This file provides an introductory tour of GenArrow.jl by generating and storing traces from a space-intensive generative function.

using Gen
using GenArrow
using TOML
using FilePathsBase
using LinearAlgebra

# Here, we define a model and a submodel.

@gen function submodel()
  for k in 1:2
    {:y => k => k} ~ normal(0.0, 1.0)
  end
end

@gen function model()
  for k in 1:3
    {:x => k => k} ~ mvnormal(zeros(2), I(2))
  end
  q ~ submodel()
end

# To create a `GenArrow.jl` managed directory, we pass a path into
# `activate`. `activate` returns a `ctx::SerializationContext` - 
# \
# a management structure which provides interfaces to read/write serialized
# output.
traces = []
activate(Path("./sample")) do ctx
  handler = GenArrow.create_handler!(ctx, "norm")
  # handler2 = GenArrow.create_handler!(ctx, "gauss")
  # Here, we sample a `tr::Gen.Trace` for our model.
  # Then, we save it to the serialization directory
  # with `GenArrow.write!`
  tr = simulate(model, ())
  tr2 = simulate(model, ())
  traces = [tr, tr2]
  # GenArrow.write!(handler, traces)
  # GenArrow.write!(handler2, traces)
  # GenArrow.write!(handler, tr)
  GenArrow.write!(handler, tr, "what")
  # GenArrow.write!(ctx, traces)
  # `GenArrow` keeps track of each trace using a UUID.

  # Multiple `write!` statements are perfectly acceptable.
  tr = simulate(model, ())
end

# Now, once we have a serialization directory, we may want to query it later,
# to perform analysis on the traces we sampled from our models or inference
# algorithms.
trace_path = Path("./sample/norm/what")
trace, weight = GenArrow.deserialize(model, trace_path)
display(trace)
println("Weight ", weight)
end # module
