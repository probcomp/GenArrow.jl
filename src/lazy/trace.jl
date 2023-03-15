mutable struct LazyTrace <: Trace
    # gen_fn::T
    trie::Trie{Any,Gen.ChoiceOrCallRecord}
    isempty::Bool
    score::Float64
    noise::Float64
    args::Tuple
    retval::Any
    function LazyTrace(args)
        trie = Trie{Any,Gen.ChoiceOrCallRecord}()
        # retval is not known yet
        new(trie, true, 0, 0, args)
    end
end

Gen.set_retval!(trace::LazyTrace, retval) = (trace.retval = retval)

Gen.has_choice(trace::LazyTrace, addr)= haskey(trace.trie, addr) && trace.trie[addr].is_choice

Gen.has_call(trace::LazyTrace, addr) = haskey(trace.trie, addr) && !trace.trie[addr].is_choice

function Gen.get_choice(trace::LazyTrace, addr)
    choice = trace.trie[addr]
    if !choice.is_choice
        throw(KeyError(addr))
    end
    Gen.ChoiceRecord(choice)
end

function Gen.get_call(trace::LazyTrace, addr)
    call = trace.trie[addr]
    if call.is_choice
        throw(KeyError(addr))
    end
    CallRecord(call)
end

function Gen.add_choice!(trace::LazyTrace, addr, retval, score)
    if haskey(trace.trie, addr)
        error("Value or subtrace already present at address $addr.
            The same address cannot be reused for multiple random choices.")
    end
    trace.trie[addr] = Gen.ChoiceOrCallRecord(retval, score, NaN, true)
    trace.score += score
    trace.isempty = false
end

function Gen.add_call!(trace::LazyTrace, addr, subtrace)
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

Gen.get_args(trace::LazyTrace) = trace.args
Gen.get_retval(trace::LazyTrace) = trace.retval
Gen.get_score(trace::LazyTrace) = trace.score
# get_gen_fn(trace::LazyTrace) = trace.gen_fn

function Gen.get_choices(trace::LazyTrace)
    if !trace.isempty
        Gen.DynamicDSLChoiceMap(trace.trie)
    else
        EmptyChoiceMap()
    end
end

function Gen._getindex(trace::LazyTrace, trie::Trie, addr::Pair)
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

function Gen._getindex(trace::LazyTrace, trie::Trie, addr)
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