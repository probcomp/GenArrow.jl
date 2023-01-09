struct GenTable
  metadata_table::Union{Arrow.Table,Nothing} # This is temporary for Cora
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
