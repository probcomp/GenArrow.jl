module GenArrowPose

include("uniformPose.jl")
using Gen
using FilePathsBase
using GenArrow

@gen function model()
    for k in 1:2
        # {:y => k => k} ~ normal(0.0, 1.0)
        p ~ UniformPoseModule.uniformPose(-10,10,-10,10,-10,10)
    end
end

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

end #module