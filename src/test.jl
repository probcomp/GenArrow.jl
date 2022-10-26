import Arrow
using Query
import FilePathsBase
using DataFrames

d1 = (name=[1, 2, 3], age=[3, 4, 5])
paths_file = FilePathsBase.Path("./src/test.arrow")
open(paths_file, "w") do io
  Arrow.write(io, d1)
end

tbl = Tables.datavaluerows(Arrow.Table(paths_file))

# x = @from(i in tbl, begin
#   @select i
# end)
q = Meta.parse("begin @select i end")
function foo(q)
  println(typeof(q))
end
print(foo(q))
# print(typeof(q))
x = @from(i in tbl, q)
# print(x)
