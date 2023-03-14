mutable struct LazyTrace{T} <: Trace
    # gen_fn
    trie::PTrie
    isempty::Bool
    score::Float64
    noise::Float64
    args::Tuple
    retval::Any
end

##############
# Traces GFI #
##############

get_args(trace::LazyTrace) = trace.args
get_retval(trace::LazyTrace) = trace.retval
get_score(trace::LazyTrace) = trace.score
# get_gen_fn(trace::LazyTrace) = trace.gen_fn

function get_choices(trace::LazyTrace)
end

mutable struct LazyChoiceMap <: ChoiceMap
end

Base.isempty(::LazyChoiceMap) = nothing 

has_value(choices::LazyChoiceMap, addr::Pair) = _has_value(choices, addr)
get_value(choices::LazyChoiceMap, addr::Pair) = _get_value(choices, addr)
get_submap(choices::LazyChoiceMap, addr::Pair) = _get_submap(choices, addr)

function get_submap(choices::LazyChoiceMap, addr)
end

function has_value(choices::DynamicDSLChoiceMap, addr)
end

function get_value(choices::DynamicDSLChoiceMap, addr)
end

function get_values_shallow(choices::DynamicDSLChoiceMap)
end

function get_submaps_shallow(choices::DynamicDSLChoiceMap)
end

## Base.getindex ##

function _getindex(trace::DynamicDSLTrace, trie::Trie, addr::Pair)
end

function _getindex(trace::DynamicDSLTrace, trie::Trie, addr)
end

function Base.getindex(trace::DynamicDSLTrace, addr)
end