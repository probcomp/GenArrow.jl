include("trace.jl")

# include("backprop.jl")
include("project.jl")
# include("regenerate.jl")
# include("update.jl")

function convert_to_dynamic(gen_fn, trace::LazyTrace)
    dynamic_trace = Gen.DynamicDSLTrace(gen_fn, get_args(trace))
    dynamic_trace.trie = trace.trie
    dynamic_trace.isempty = trace.isempty
    dynamic_trace.score = trace.score
    dynamic_trace.noise = trace.noise
    dynamic_trace.args = trace.args
    dynamic_trace.retval = trace.retval
    dynamic_trace
end

export LazyTrace, LazyChoiceMap