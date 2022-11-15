module GenArrowPose
using Arrow
using FilePathsBase
using ArrowTypes

# overload interface method for custom type Person; return a symbol as the "name"
# this instructs Arrow.write what "label" to include with a column with this custom type
# ArrowTypes.arrowname(::Type{Person}) = :Person
# overload JuliaType on `Val{:Person}`, which is like a dispatchable string
# return our custom *type* Person; this enables Arrow.Table to know how the "label"
# on a custom column should be mapped to a Julia type and deserialized
# ArrowTypes.JuliaType(::Val{:Person}) = Person

table = (col1=[1=>3=>4, 2=>3=>4=>5, "a"=>4=>4], col2=["a", "b", "c"])
io = IOBuffer()
Arrow.write(io, table)
seekstart(io)
table2 = Arrow.Table(io)
table2[2]
end