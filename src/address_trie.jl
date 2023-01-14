#####
##### TraceCollection
#####

# Want this to have struct-of-array representation semantics.
struct TraceCollection <: Trace
  args::Any
  retval::Any
  choices::Any
  broadcast_axis_length::Int
end

#####
##### GFI methods for TraceCollection
#####

get_gen_fn(_::TraceCollection) = throw("Not supported for TraceCollection.")

function Gen.get_args(tr::TraceCollection)
  return tr.args
end

function Gen.get_retval(tr::TraceCollection)
  return tr.retval
end

function Gen.get_choices(tr::TraceCollection)
  return tr.choices
end

#####
##### Functional-inspired patterns
#####

function lift(tr::Gen.Trace)
  args = get_args(tr)
  retval = get_retval(tr)
  choices = DynamicChoiceMap(get_choices(tr)) # TODO: check if okay.
  choices = vectorize(choices)
  return TraceCollection(
    Union{Missing,typeof(args)}[args],
    Union{Missing,typeof(retval)}[retval],
    choices,
    1,
  )
end

function functor(fn::Function, choices::ChoiceMap)
  new_chm = DynamicChoiceMap()
  for (key, value) in get_values_shallow(choices)
    new_chm.leaf_nodes[key] = fn(value)
  end
  for (key, node) in get_submaps_shallow(choices)
    new_submap = functor(fn, node)
    new_chm.internal_nodes[key] = new_submap
  end
  return new_chm
end

function functor!(fn::Function, choices::ChoiceMap)
  for (key, value) in get_values_shallow(choices)
    choices.leaf_nodes[key] = fn(value)
  end
  for (_, node) in get_submaps_shallow(choices)
    functor!(fn, node)
  end
end

function functor(fn::Function, coll::TraceCollection)
  args = fn(get_args(coll))
  retval = fn(get_retval(coll))
  choices = functor(fn, get_choices(coll))
  return TraceCollection(args, retval, choices, coll.broadcast_axis_length)
end

function functor!(fn::Function, coll::TraceCollection)
  args = fn(get_args(coll))
  retval = fn(get_retval(coll))
  choices = functor!(fn, get_choices(coll))
  return TraceCollection(args, retval, choices, coll.broadcast_axis_length)
end

vectorize(choices) = functor(v -> Union{Missing,typeof(v)}[v], choices)

function append_missing!(g, broadcast_axis_length)
  return functor!(v -> append!(v, (missing for _ in 1:broadcast_axis_length)), g)
end

function prepend_missing!(g, broadcast_axis_length)
  return functor!(v -> prepend!(v, (missing for _ in 1:broadcast_axis_length)), g)
end

TraceCollection(tr::Gen.Trace) = lift(tr)

# The first choice map is mutated in place.
function accumulate!(broadcast_axis_length::Int, choices::DynamicChoiceMap, choices2::ChoiceMap)

  # These two blocks handle the shallow values (leaves).
  for (key, value) in get_values_shallow(choices2)
    if haskey(choices.leaf_nodes, key)
      v = choices.leaf_nodes[key]
      push!(v, value)
    else
      v = Union{Missing,typeof(value)}[(missing for _ in 1:broadcast_axis_length)..., value]
      choices.leaf_nodes[key] = v
    end
  end

  for (_, value) in get_values_shallow(choices)
    if length(value) == broadcast_axis_length
      push!(value, missing)
    end
  end

  # Handle the inner nodes.
  for (key, node) in get_submaps_shallow(choices2)
    if haskey(choices.leaf_nodes, key)
      error("choices1 has leaf node at $key and choices2 has internal node at $key")
    end
    if !haskey(choices.internal_nodes, key)
      new_collection = lift(node)
      prepend_missing!(broadcast_axis_length, new_collection)
    else
      accumulate!(choices.internal_nodes[key], node)
    end
  end

  for (key, node) in get_submaps_shallow(choices)
    submap = get_submap(choices2, key)
    if submap isa EmptyChoiceMap
      append_missing!(broadcast_axis_length, node)
    end
  end

  return choices
end


function accumulate!(tr1::TraceCollection, tr2::Gen.Trace)
  push!(tr1.args, get_args(tr2))
  push!(tr1.retval, get_retval(tr2))
  choices_1 = get_choices(tr1)
  choices_2 = get_choices(tr2)
  accumulate!(tr1.broadcast_axis_length, choices_1, choices_2)
  return TraceCollection(
    tr1.args, tr1.retval, choices_1, tr1.broadcast_axis_length + 1
  )
end
