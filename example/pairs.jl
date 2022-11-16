module GenArrowPose
using Arrow

data = (a=[1,2,3],b=[4,5,6])
io = IOBuffer()
Arrow.write(io, data,)
seekstart(io)
Arrow.append(io, data)
println(Arrow.Table(io))
end