# mutable struct LazyDeserializeState
#     trace::LazyTrace
#     io::IO # Change to blob
#     ptr_trie::Gen.PTrie{Any, RECORD_TYPE}
#     visitor::Gen.AddressVisitor
#     params::Dict{Symbol,Any}
# end

# function _deserialize_maps(io, ptr_trie::PTrie{Any, RECORD_TYPE}, prefix::Tuple)

#     current_trie = io.ptr
#     leaf_map_ptr = read(io, Int)
#     internal_map_ptr = read(io, Int)
#     @debug "[LEAF MAP] [INTERNAL MAP PTR]" current_trie leaf_map_ptr internal_map_ptr
#     leaf_count = read(io, Int)
#     @debug "LEAF COUNT" leaf_count
#     for i=1:leaf_count
#         addr = foldr(=> , (prefix..., Serialization.deserialize(io)))
#         record_ptr = read(io, Int)
#         record_size = read(io, Int)
#         is_trace = read(io, Bool)

#         ptr_trie[addr] = (record_ptr=record_ptr, record_size=record_size, is_trace=is_trace)
#         @debug "LEAF" addr record_ptr size=record_size is_trace
#     end

#     internal_count = read(io, Int)
#     @debug "INTERNAL COUNT" internal_count
#     for i=1:internal_count
#         flattened_addr = (prefix..., Serialization.deserialize(io))
#         addr = foldr(=> , flattened_addr)
#         trie_ptr = read(io, Int)
#         trie_size = read(io,Int)
#         @debug "INTERNAL" addr trie_ptr trie_size  

#         internal_node = PTrie{Any, RECORD_TYPE}()
#         Gen.set_internal_node!(ptr_trie, addr, internal_node)

#         restore_ptr = io.ptr
#         io.ptr = trie_ptr # Next trie
#         _deserialize_maps(io, ptr_trie, flattened_addr)
#         io.ptr = restore_ptr
#     end

#     @debug "MAP" ptr_trie _module=""

#     ptr_trie
# end

# function GFDeserializeState(gen_fn, io, params)
#     trace_type = Serialization.deserialize(io)
#     isempty = read(io, Bool)
#     score = read(io, Float64)
#     noise = read(io, Float64)
#     args = Serialization.deserialize(io)
#     retval = Serialization.deserialize(io)

#     @debug "DESERIALIZE" type=trace_type isempty score noise args retval gen_fn _module=""
#     ptr_trie = PTrie{Any, RECORD_TYPE}()
#     _deserialize_maps(io, ptr_trie, ())
#     if isempty
#         throw("Need to figure this out")
#     else
#         @debug "TODO: Non-empty?" _module=""
#     end

#     # Populate trace with choices that are not subtraces_count
#     # Populate state with to be determined subtrace addr => blanks

#     trace = Gen.DynamicDSLTrace(gen_fn, args) 
#     trace.isempty = isempty
#     # trace.score = score # add_call! and add_choice! double count
#     trace.noise = noise
#     trace.retval = retval
#     LazyDeserializeState(trace, io, ptr_trie, Gen.AddressVisitor(), params)
# end

# function Gen.traceat(state::LazyDeserializeState, dist::Gen.Distribution{T}, args, key) where {T}
#     local retval::T

#     # check that key was not already visited, and mark it as visited
#     Gen.visit!(state.visitor, key)

#     # check if leaf_map or internal_map contains key

#     if haskey(state.ptr_trie, key)
#         ptr, size ,is_trace = state.ptr_trie[key]
#         state.io.ptr = ptr
#         # record = Serialization.deserialize(state.io)
#         score = read(state.io, Float64)
#         noise = read(state.io, Float64)
#         is_choice = read(state.io, Bool)
#         subtrace_or_retval = Serialization.deserialize(state.io)
#         record = Gen.ChoiceOrCallRecord(subtrace_or_retval, score, noise, is_choice)
#         @debug "CHOICE" ptr size is_trace record
#     else
#         @warn "LOST KEY" key state.ptr_trie _module=""
#         throw("$(key) Key not in leaf or internal maps")
#     end


#     retval = record.subtrace_or_retval
#     # Check if it is truly a retval

#     # constrained = has_value(state.constraints, key)
#     # !constrained && check_no_submap(state.constraints, key)

#     # intercept logpdf
#     score = record.score
#     @debug "TRACEAT DIST" key record score retval args dist

#     # add to the trace
#     Gen.add_choice!(state.trace, key, retval, score)

#     # increment weight
#     # if constrained
#         # state.weight += score
#     # end

#     retval
# end

# function Gen.traceat(state::LazyDeserializeState, gen_fn::Gen.GenerativeFunction{T,U},
#               args, key) where {T,U}
#     local subtrace::U
#     local retval::T

#     @debug "TRACEAT GENFUNC" gen_fn args key
#     # check key was not already visited, and mark it as visited
#     Gen.visit!(state.visitor, key)

#     # check for constraints at this key
#     if haskey(state.ptr_trie, key)
#         ptr, size ,is_trace = state.ptr_trie[key]
#         state.io.ptr = ptr
#         @debug "SUBTRACE" ptr size is_trace
#     else
#         @warn "LOST KEY" key state.ptr_trie.leaf_nodes state.internal_map _module=""
#         throw("$(key) Key not in leaf or internal maps")
#     end

#     # get subtrace
#     subtrace = _deserialize(gen_fn, state.io)

#     # add to the trace
#     Gen.add_call!(state.trace, key, subtrace)

#     # update weight
#     # state.weight += weight # TODO: What?

#     # get return value
#     retval = get_retval(subtrace) 

#     retval
# end

# function Gen.splice(state::LazyDeserializeState, gen_fn::Gen.DynamicDSLFunction,
#                 args::Tuple)
#     println("Splice")
#     prev_params = state.params
#     state.params = gen_fn.params
#     retval = Gen.exec(gen_fn, state, args)
#     state.params = prev_params
#     retval
# end

# function _deserialize(gen_fn::Gen.DynamicDSLFunction, io::IO, lazy)
#     state = GFDeserializeState(gen_fn, io, gen_fn.params)
#     # Deserialize stuff including args and retval
#     _ = Gen.exec(gen_fn, state, state.trace.args)
#     Gen.set_retval!(state.trace, get_retval(state.trace))
#     @debug "END" tr=get_choices(state.trace)
#     state.trace
# end