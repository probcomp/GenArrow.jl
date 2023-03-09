using Gen
import .Serialization

mutable struct GFDeserializeState
    trace::Gen.DynamicDSLTrace
    io::IOBuffer # Change to blob
    visitor::Gen.AddressVisitor
    params::Dict{Symbol,Any}
end

function _deserialize_trie(io)
    temp_subtraces = Dict()
    leaf_count = read(io, Int64)
    println("leaf count: ", leaf_count)
    # Leaf nodes
    trie = Trie{Any, Gen.ChoiceOrCallRecord}()
    for i=1:leaf_count
        key = Serialization.deserialize(io)
        is_trace = read(io, Bool)
        println("Key: ", key)
        println("is trace: ", is_trace)
        record = nothing
        if is_trace
            # Blob: Record 
            # println("Blob: ", temp_subtraces[key])
            # TODO: Get blob size of subtrace. Grab?
            # type = Serialization.deserialize(io)
            # # println("Subtrace type: ", type)
            # GenArrow._deserialize(io, type)
        else
            record = Serialization.deserialize(io)
        end
        trie.leaf_nodes[key] = record
    end

    # Internal nodes
    internal_count = read(io, Int64)
    # println("Deserialize Internal Nodes: ", internal_count)
    for i=1:internal_count
        key = Serialization.deserialize(io)
        subtrie = deserialize_trie(io)
        trie.internal_nodes[key] = subtrie
        # How to map this subtrie into key
    end
    return trie
end

function GFDeserializeState(gen_fn, io, params)
    isempty = read(io, Bool)
    score = read(io, Float64)
    noise = read(io, Float64)
    args = Serialization.deserialize(io)
    retval = Serialization.deserialize(io)

    println("Deserialize")
    println("isempty: ", isempty)
    println("score: ", score)
    println("noise: ", noise)
    println("args: ", args)
    println("retval: ", retval)
    if isempty
        throw("Need to figure this out")
    else
        _deserialize_trie(io)
    end

    # Populate trace with choices that are not subtraces_count
    # Populate state with to be determined subtrace addr => blanks

    trace = Gen.DynamicDSLTrace(gen_fn, args) # TODO: What?
    trace.isempty = isempty
    trace.score = score
    trace.noise = noise
    trace.retval = retval
    GFDeserializeState(trace, io, Gen.AddressVisitor(), params)
end

function Gen.traceat(state::GFDeserializeState, dist::Gen.Distribution{T}, args, key) where {T}
    local retval::T
    println("Dist")

    # check that key was not already visited, and mark it as visited
    Gen.visit!(state.visitor, key)

    # check for constraints at this key
    constrained = has_value(state.constraints, key)
    !constrained && check_no_submap(state.constraints, key)

    # get return value
    if constrained
        retval = get_value(state.constraints, key)
    else
        retval = random(dist, args...)
    end

    # compute logpdf
    score = logpdf(dist, retval, args...)

    # add to the trace
    add_choice!(state.trace, key, retval, score)

    # increment weight
    if constrained
        state.weight += score
    end

    retval
end

function Gen.traceat(state::GFDeserializeState, gen_fn::Gen.GenerativeFunction{T,U},
              args, key) where {T,U}
    local subtrace::U
    local retval::T

    println("GenFunc")
    println("key: ", key)
    # check key was not already visited, and mark it as visited
    Gen.visit!(state.visitor, key)

    # check for constraints at this key
    # constraints = get_submap(state.constraints, key)

    # get subtrace
    subtrace = _deserialize(gen_fn, state.io)

    # add to the trace
    Gen.add_call!(state.trace, key, subtrace)

    # update weight
    # state.weight += weight # TODO: What?

    # get return value
    retval = get_retval(subtrace) # TODO: Do we need to intercept?

    retval
end

function Gen.splice(state::GFDeserializeState, gen_fn::Gen.DynamicDSLFunction,
                args::Tuple)
    println("Splice")
    prev_params = state.params
    state.params = gen_fn.params
    retval = Gen.exec(gen_fn, state, args)
    state.params = prev_params
    retval
end

function _deserialize(gen_fn::Gen.DynamicDSLFunction, io::IOBuffer)
    # HEADER 
    # isempty, score, noise, args, retval, [trie]
    # [trie] is present if isempty is false

    trace_type = Serialization.deserialize(io)
    
    state = GFDeserializeState(gen_fn, io, gen_fn.params)
    # Deserialize stuff including args and retval
    retval = Gen.exec(gen_fn, state, state.trace.args)
    # set_retval!(state.trace, retval)
    state.trace
end