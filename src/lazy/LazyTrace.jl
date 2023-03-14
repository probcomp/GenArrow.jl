mutable struct LazyTrace{T} <: Trace
    # gen_fn::T
    trie::PTrie{Any,Gen.ChoiceOrCallRecord}
    isempty::Bool
    score::Float64
    noise::Float64
    args::Tuple
    retval::Any
    function LazyTrace{T}(args) where {T}
        trie = PTrie{Any,Gen.ChoiceOrCallRecord}(-1, -1)
        # retval is not known yet
        new{T}(trie, true, 0, 0, args)
    end
end

set_retval!(trace::LazyTrace, retval) = (trace.retval = retval)

function has_choice(trace::LazyTrace, addr)
    haskey(trace.trie, addr) && trace.trie[addr].is_choice
end

function has_call(trace::LazyTrace, addr)
    haskey(trace.trie, addr) && !trace.trie[addr].is_choice
end


function get_choice(trace::LazyTrace, addr)
    choice = trace.trie[addr]
    if !choice.is_choice
        throw(KeyError(addr))
    end
    Gen.ChoiceRecord(choice)
end

function get_call(trace::LazyTrace, addr)
    call = trace.trie[addr]
    if call.is_choice
        throw(KeyError(addr))
    end
    CallRecord(call)
end

function add_choice!(trace::LazyTrace, addr, retval, score)
    if haskey(trace.trie, addr)
        error("Value or subtrace already present at address $addr.
            The same address cannot be reused for multiple random choices.")
    end
    trace.trie[addr] = Gen.ChoiceOrCallRecord(retval, score, NaN, true)
    trace.score += score
    trace.isempty = false
end

function add_call!(trace::LazyTrace, addr, subtrace)
    if haskey(trace.trie, addr)
        error("Value or subtrace already present at address $addr.
            The same address cannot be reused for multiple random choices.")
    end
    score = get_score(subtrace)
    noise = project(subtrace, EmptySelection())
    submap = get_choices(subtrace)
    trace.isempty = trace.isempty && isempty(submap)
    trace.trie[addr] = Gen.ChoiceOrCallRecord(subtrace, score, noise, false)
    trace.score += score
    trace.noise += noise
end


##############
# Traces GFI #
##############

get_args(trace::LazyTrace) = trace.args
get_retval(trace::LazyTrace) = trace.retval
get_score(trace::LazyTrace) = trace.score
# get_gen_fn(trace::LazyTrace) = trace.gen_fn

function get_choices(trace::LazyTrace)
    if !trace.isempty
        LazyChoiceMap(trace.trie)
    else
        EmptyChoiceMap()
    end
end

mutable struct LazyChoiceMap <: ChoiceMap
    trie::PTrie{Any, Gen.ChoiceOrCallRecord}
end

# get_address_schema(::Type{LazyTrace}) = LazyAddressSchema()
Base.isempty(::LazyChoiceMap) = nothing 
has_value(choices::LazyChoiceMap, addr::Pair) = _has_value(choices, addr)
get_value(choices::LazyChoiceMap, addr::Pair) = _get_value(choices, addr)
get_submap(choices::LazyChoiceMap, addr::Pair) = _get_submap(choices, addr)

function get_submap(choices::LazyTrace, addr)
    trie = choices.trie
    if has_leaf_node(trie, addr)
        # leaf node, must be a call
        call = trie[addr]
        if call.is_choice
            throw(KeyError(addr))
        end
        get_choices(call.subtrace_or_retval)
    elseif has_internal_node(trie, addr)
        # internal node
        subtrie = get_internal_node(trie, addr)
        LazyChoiceMap(subtrie) # see below
    else
        EmptyChoiceMap()
    end
end

function has_value(choices::LazyTrace, addr)
    trie = choices.trie
    has_leaf_node(trie, addr) && trie[addr].is_choice
end

function get_value(choices::LazyTrace, addr)
    trie = choices.trie
    choice = trie[addr]
    if !choice.is_choice
        throw(KeyError(addr))
    end
    choice.subtrace_or_retval
end

function get_values_shallow(choices::LazyTrace)
    ((key, choice.subtrace_or_retval)
     for (key, choice) in get_leaf_nodes(choices.trie)
     if choice.is_choice)
end

function get_submaps_shallow(choices::LazyTrace)
    calls_iter = ((key, get_choices(call.subtrace_or_retval))
        for (key, call) in get_leaf_nodes(choices.trie)
        if !call.is_choice)
    internal_nodes_iter = ((key, LazyChoiceMap(trie))
        for (key, trie) in get_internal_nodes(choices.trie))
    Iterators.flatten((calls_iter, internal_nodes_iter))
end

## Base.getindex ##

function _getindex(trace::LazyTrace, trie::Trie, addr::Pair)
    (first, rest) = addr
    if haskey(trie.leaf_nodes, first)
        choice_or_call = trie.leaf_nodes[first]
        if choice_or_call.is_choice
            error("Unknown address $addr; random choice at $first")
        else
            subtrace = choice_or_call.subtrace_or_retval
            return subtrace[rest]
        end
    elseif haskey(trie.internal_nodes, first)
        return _getindex(trace, trie.internal_nodes[first], rest)
    else
        error("No random choice or generative function call at address $addr")
    end
end

function _getindex(trace::LazyTrace, trie::Trie, addr)
    if haskey(trie.leaf_nodes, addr)
        choice_or_call = trie.leaf_nodes[addr]
        if choice_or_call.is_choice
            # the value of the random choice
            return choice_or_call.subtrace_or_retval
        else
            # the return value of the generative function call
            return get_retval(choice_or_call.subtrace_or_retval)
        end
    else
        error("No random choice or generative function call at address $addr")
    end
end

function Base.getindex(trace::LazyTrace, addr)
    _getindex(trace, trace.trie, addr)
end
