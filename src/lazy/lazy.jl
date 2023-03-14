include("trace.jl")

# include("backprop.jl")
include("project.jl")
# include("regenerate.jl")
# include("update.jl")

function convert_to_dynamic(gen_fn, trace::LazyTrace)
    trace 
end

export LazyTrace, LazyChoiceMap