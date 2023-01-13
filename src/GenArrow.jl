module GenArrow

using Arrow
using Gen
import Gen: Trace, get_args, get_retval, get_gen_fn, get_choices
using Tables
using DataFrames
using FilePathsBase
using Serialization

# Address index trie.
include("address_trie.jl")

# Handles user interaction for serialization.
include("context_manager.jl")

# Core serialization functionality.
#include("serialize.jl")

# Handles deserialization.
#include("partial_trace.jl")

end
