using JLD2

jldopen("example.jld2", "w") do f
  f["file/what"] = 100
end
f = jldopen("example.jld2", "r")
display(f)
close(f)

