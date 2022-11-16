module GenTableStruct
using Arrow

export GenTable

struct GenTable
  metadata_table::Arrow.Table
  choice_table::Arrow.Table
  addrs_trie
  addrs_dict
end

function Base.getindex(gentable::GenTable, address::Pair)
  try
    return gentable.choice_table[Symbol(address)]
  catch e
    throw(KeyError("$(address)"))
  end
end

end # End Module
