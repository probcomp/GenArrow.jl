module PartialTraceScratch

using Gen
using GenArrow

@gen function submodel()
  z ~ normal(0.0, 1.0)
end

@gen function model(v::Bool)
  if v
    x ~ normal(0.0, 1.0)
  else
    y ~ normal(0.0, 1.0)
    q ~ submodel()
  end
end

tr1 = simulate(model, (true,))
tr2 = simulate(model, (false,))
tr3 = simulate(model, (false,))

test = () -> begin
  partial = GenArrow.lift(tr1)
  partial = GenArrow.accumulate!(partial, tr2)
  partial = GenArrow.accumulate!(partial, tr3)
  println(partial)
end

#test()
println(tr2)
println()
for (k, v) in get_submaps_shallow(get_choices(tr2))
  println(k)
  println(v)
end

end # module
