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
  col = gentable.addrs_dict[address]
  try
    return gentable.choice_table[Symbol(col)]
  catch e
    throw(KeyError("$(address)"))
  end
end

end # End Module
