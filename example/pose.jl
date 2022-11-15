module GenArrowPose
include("uniformPose.jl")
using Gen
using GenArrow
using FilePathsBase
using Rotations
using PoseComposition: Pose
using ArrowTypes
using GenDirectionalStats
import StaticArrays: StaticVector, SVector, @SVector

# Use structs as a distribution in demo.
ArrowTypes.JuliaType(::Val{:Pose}) = Pose
ArrowTypes.arrowname(::Type{Pose}) = :Pose
ArrowTypes.JuliaType(::Val{:Rotation}) = Rotation
ArrowTypes.arrowname(::Type{Rotation}) = :Rotation

function ArrowTypes.fromarrow(::Type{Pose}, pos::Vector{Float64}, orientation::Vector{Float64})
  o = Rotations.RotMatrix{3}(reshape(orientation, (3, 3)))
  quat = Rotations.QuatRotation{Float64}(o)
  p = SVector(pos...)
  Pose(p, quat)
end

@gen function model()
  for k in 1:2
    {:y => k => k} ~ UniformPoseModule.uniformPose(-10, 10, -10, 10, -10, 10)
  end
end

# @gen function model()
# k = 1
# {:x=>k} ~ uniform_rot3()
# end
tr = simulate(model, ())
display(get_choices(tr))

GenArrow.activate(Path("./sample")) do ctx
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
