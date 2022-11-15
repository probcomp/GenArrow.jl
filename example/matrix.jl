module GenArrowPose
using Arrow
using FilePathsBase
using ArrowTypes

struct NewMatrix
  id::Int32
  mat::Matrix{Int}
end

ArrowTypes.arrowname(::Type{NewMatrix}) = Symbol(NewMatrix)
ArrowTypes.JuliaType(::Val{Symbol(NewMatrix)}) = NewMatrix
ArrowTypes.default(::Type{Matrix{Int8}}) = ones(Int8, 2, 3)
function ArrowTypes.fromarrow(::Type{NewMatrix}, x...)
  println("What ? ", x)
  NewMatrix(x[1], zeros(Int8, 2, 3))
end
m1 = NewMatrix(1, zeros(Int8, 2, 3))
m2 = NewMatrix(2, zeros(Int8, 2, 3))
m3 = NewMatrix(3, zeros(Int8, 2, 3))
m4 = NewMatrix(4, zeros(Int8, 2, 3))
# m4 = NewMatrix(nothing, zeros(Int8, 2, 3))

data = (a=[m1, m2], b=[m3, m4]) # Works
# data = (a=[m1, m2], b=[m3, nothing]) # Works
# data = (a=[m1, m2], b=[zeros(Int8, 2, 3), missing]) # Works
# data = (a=[m1, m2], b=[m3, missing]) # Fails
# data = Vector((a=[1, 2, 3], b=[1, 34, 5, 7], c=3))
# ArrowTypes.default(::Type{NewMatrix}) = NewMatrix(1, zeros(Int8, 2, 3))
# println(ArrowTypes.default(typeof(m1)))
# println(ArrowTypes.default(typeof(zeros(Int8, 2, 3))))
io = IOBuffer()
Arrow.write(io, data)
seekstart(io)
table2 = Arrow.Table(io)
println(table2[:b])
end
