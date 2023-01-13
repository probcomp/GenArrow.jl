#####
##### Address Trie
#####

AddressIndexTrie = Gen.Trie{Any,Int}

#####
##### Covering choice map
#####

struct CoveringChoiceMap <: Gen.ChoiceMap
  trie:Gen.Trie{Any,Any}
end

struct PartialTrace <: Gen.Trace
  address_trie::AddressIndexTrie
  args::Arrow.Table
  retvals::Arrow.Table
  choices::Arrow.Table
end

#####
##### Generative function interface
#####

# NOTE: These are stub methods to implement the trace interfaces.
#
# The point of `PartialTrace` is to support slicing across 
# collections of traces using a struct-of-array representation. 

function get_gen_fn(trace::PartialTrace)
end

function get_args(trace::PartialTrace)
  return trace.args
end

function get_retval(trace::PartialTrace)
  return trace.retvals
end

#####
##### Slicing
#####

function get_column(table::Arrow.Table, leaf_index::Int)
  return table[leaf_index]
end

function get_slice(trace::PartialTrace, leaf_index::Int)
  args = get_column(trace.args, leaf_index)
  retvals = get_column(trace.retvals, leaf_index)
  choices = get_column(trace.choices, leaf_index)
  return PartialTrace(trace.address_trie, args, retvals, choices)
end

#####
##### Indexing into choices with an addr
#####

function getindex(trace::PartialTrace, addr)
  addr_index = getindex(trace.address_trie, addr)
  choices = get_column(trace.choices, addr_index)
  return choices
end
