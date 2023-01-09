

# A new interface which users can implement for their `T::Trace`
# type to extract serializable arguments.
function get_serializable_args(tr::T) where {T<:Gen.Trace}
  return Gen.get_args(tr)
end

function save(dir::AbstractPath, tr::Gen.Trace, df::DataFrame; user_provided_metadata)
  # TODO: Implement the single trace version. 
end

# TODO: Move to Serialize.jl
function save(dir::AbstractPath, traces::Vector{<:Gen.Trace}, df::DataFrame; user_provided_metadata)
  metadata_path = FilePathsBase.join(dir, "metadata.arrow")
  addrs_trie_path = FilePathsBase.join(dir, "addrs_trie.jls")
  addrs_dict_path = FilePathsBase.join(dir, "addrs_dict.jls")
  choices_path = FilePathsBase.join(dir, "choices.arrow")

  # Construct super-trie and populate df
  metadata = []
  address_trie = InnerNode()
  address_dict = Dict()
  # Metadata arrow table contains ret, args, score, gen_fn, user_provided_metadata
  for tr in traces
    ret = get_retval(tr)
    args = get_serializable_args(tr)
    score = get_score(tr)
    gen_fn = repr(get_gen_fn(tr))
    push!(metadata, (ret=ret, args=args, score=score, gen_fn=gen_fn))
    row, _, _ = traverse(tr, address_trie, address_dict)
    push!(df, row, cols=:union)
  end

  # Flush to arrow?
  args = []
  for meta in metadata
    push!(args, (; args=meta.args))
  end
  Arrow.write(metadata_path, args)
  serialize(string(addrs_trie_path), address_trie)
  serialize(string(addrs_dict_path), address_dict)

  Arrow.write(choices_path, df)
  return address_trie, address_dict, df
end

# TODO: Move to Serialize.jl
function address_to_symbol(addr::Tuple)
  if length(addr) == 1
    return addr[1]
  end
  sym = reduce((addr, y) -> Pair(y, addr), reverse(addr))
end

# TODO: Move to Serialize.jl
function traverse!(chm::Gen.ChoiceMap, row, addrs_trie::AddressTree, addrs_dict::Dict, prefix::Tuple, count::Int)
  for (k, v) in get_values_shallow(chm)
    addr = (prefix..., k)
    key = address_to_symbol(addr) # TODO: Address speed of this
    row[Symbol(key)] = v
    if !haskey(addrs_dict, key)
      addrs_dict[key] = count
      addrs_trie[addr] = count
    end
    count += 1

  end

  for (k, subchm) in get_submaps_shallow(chm)
    count = traverse!(subchm, row, addrs_trie, addrs_dict, (prefix..., k), count)
  end
  return count
end

# TODO: Move to Serialize.jl
function traverse(tr::Gen.Trace, row, addrs_trie::AddressTree, addrs_dict::Dict)
  leaves = traverse!(get_choices(tr), row, addrs_trie, addrs_dict, tuple(), 1)
  return row, addrs_trie, addrs_dict
end
traverse(tr::Gen.Trace, addrs_trie::AddressTree, addrs_dict::Dict) = traverse(tr, Dict(), addrs_trie, addrs_dict)
traverse(tr::Gen.Trace) = traverse(tr, Dict(), InnerNode(), Dict())

# TODO: Move to Serialize.jl
function view(dir::AbstractPath; metadata=true)
  paths = Arrow.Table(dir)[:path]
  dir = Path(paths[1]) # TODO: Handle multiple writes.
  choices_path = FilePathsBase.join(dir, "choices.arrow")
  addrs_trie = deserialize("$(dir)/addrs_trie.jls")
  addrs_dict = deserialize("$(dir)/addrs_dict.jls")
  if metadata # TODO: This is temporary for application debugging
    metadata_path = FilePathsBase.join(dir, "metadata.arrow")
    return GenTable(Arrow.Table(metadata_path), Arrow.Table(choices_path), addrs_trie, addrs_dict) # Use address dictionary for type?
  else
    return GenTable(nothing, Arrow.Table(choices_path), addrs_trie, addrs_dict)
  end
end

# TODO: Move to Serialize.jl
function reconstruct_trace(gen_fn, gentable::GenTable, index::Int) # TODO: Slow. Uses strings as symbols
  df = DataFrame(gentable.choice_table)[index, :]
  columns = names(df)
  mappings = []
  for col in columns
    if !isequal(df[col], missing)
      push!(mappings, (eval(Meta.parse(col)), df[col]))
    end
  end
  args = DataFrame(gentable.metadata_table)[index, 1]
  chm = choicemap(mappings...)
  Gen.generate(gen_fn, args, chm)
end