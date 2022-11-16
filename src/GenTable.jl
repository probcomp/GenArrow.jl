module GenTableStruct
using Arrow

export GenTable

struct GenTable
  metadata_table::Arrow.Table
  choice_table::Arrow.Table
  addrs
end

function Base.getindex(gentable::GenTable, address::Pair)
  key = []
  current = address

  while isa(current, Pair)
    push!(key, current[1])
    current = current[2]
  end
  push!(key, current)
  key = Symbol(Tuple(key))
  try
    return gentable.choice_table[key]
  catch e
    throw(KeyError("$(address)"))
  end
end

end # End Module
