using Arrow
using StaticArrays: StaticArray, SVector, @SVector
using Rotations

struct Cards
    num:: Int
end

struct Person
    id::Int
    name::String
    card::Cards
end
c1 =Cards(1)

ArrowTypes.JuliaType(::Val{:Cards}) = Cards
ArrowTypes.arrowname(::Type{Cards}) = :Cards
# ArrowTypes.JuliaType(::Val{:Person}) = Person
# ArrowTypes.arrowname(::Type{Person}) = :Person
# overload JuliaType on `Val{:Person}`, which is like a dispatchable string
# return our custom *type* Person; this enables Arrow.Table to know how the "label"
# on a custom column should be mapped to a Julia type and deserialized

table = (col1=[Person(1, "Bob", c1), Person(2, "Jane", c1)],)
io = IOBuffer()
Arrow.write(io, table)
seekstart(io)
table2 = Arrow.Table(io)


s = @SVector([1,2,3])
ArrowTypes.JuliaType(::Val{:StaticArray}) = StaticArray
ArrowTypes.arrowname(::Type{StaticArray}) = :StaticArray
table = (co1=[s,])
Arrow.write("sample/svector.arrow", table)
# Arrow.toarrow(s)
