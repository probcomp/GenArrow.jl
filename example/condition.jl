module GenArrowTour

# This file provides an introductory tour of GenArrow.jl by generating and storing traces from a space-intensive generative function.

using Gen
using GenArrow
using TOML
using FilePathsBase
using LinearAlgebra

# Here, we define a model and a submodel.

@gen function good()
  for k in 1:5
    {:good => k} ~ normal(0.0, 0.1)
  end
end

@gen function bad()
  for k in 1:5
    {:bad => k} ~ normal(0.0, 3.0)
  end
end

@gen function model()
  for k in 1:10
    z = {:q => k} ~ categorical([0.5, 0.5])
    if z == 1
      {k} ~ good()
    else
      {k} ~ bad()
    end
  end
end

# To create a `GenArrow.jl` managed directory, we pass a path into
# `activate`. `activate` returns a `ctx::SerializationContext` - 
# \
# a management structure which provides interfaces to read/write serialized
# output.
traces = []
activate(Path("./sample")) do ctx
  # Here, we sample a `tr::Gen.Trace` for our model.
  # Then, we save it to the serialization directory
  # with `GenArrow.write!`
  traces = Gen.Trace[]
  for t in 1:10
    tr = simulate(model, ())
    push!(traces, tr)
  end
  GenArrow.write!(ctx, traces)
  println("Done with write to gen arrow!")
  # `GenArrow` keeps track of each trace using a UUID.
end

# Now, once we have a serialization directory, we may want to query it later,
# to perform analysis on the traces we sampled from our models or inference
# algorithms.
d = TOML.parsefile("sample/TraceManifest.toml")
d = Path("./sample/$(length(d)).arrow")
view = GenArrow.view(d)
println(view[1=>:good=>1])
end # module
