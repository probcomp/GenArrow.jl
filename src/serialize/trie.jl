##################
# Ptrie #
##################

RECORD_INFO = NamedTuple{(:record_ptr, :record_size, :is_trace), Tuple{Int64, Int64, Bool}}
struct Ptrie{K}
    ptr::Int64
    length::Int64
    leaf_nodes::Dict{K, RECORD_INFO} # Invariant: keys are not shared! TODO: Check for this
    internal_nodes::Dict{K,Ptrie{K}}
end

Ptrie{K}(ptr::Int64, length::Int64) where {K} = Ptrie(ptr, length, Dict{K,RECORD_INFO}(), Dict{K,Ptrie{K}}())

# import JSON
# Base.println(trie::Trie) = JSON.print(trie, 4)

# invariant: all internal nodes are nonempty
Base.isempty(trie::Ptrie) = isempty(trie.leaf_nodes) && isempty(trie.internal_nodes)
get_leaf_nodes(trie::Ptrie) = trie.leaf_nodes
get_internal_nodes(trie::Ptrie) = trie.internal_nodes

# function Base.values(trie::Trie)
#     iterators = convert(Vector{Any}, collect(map(values, values(trie.internal_nodes))))
#     push!(iterators, values(trie.leaf_nodes))
#     Iterators.flatten(iterators)
# end

# function has_internal_node(trie::Trie, addr)
#     haskey(trie.internal_nodes, addr)
# end

# function has_internal_node(trie::Trie, addr::Pair)
#     (first, rest) = addr
#     if haskey(trie.internal_nodes, first)
#         has_internal_node(trie.internal_nodes[first], rest)
#     else
#         false
#     end
# end

# function get_internal_node(trie::Trie, addr)
#     trie.internal_nodes[addr]
# end

# function get_internal_node(trie::Trie, addr::Pair)
#     (first, rest) = addr
#     if haskey(trie.internal_nodes, first)
#         get_internal_node(trie.internal_nodes[first], rest)
#     else
#         throw(KeyError(trie, addr))
#     end
# end

function set_internal_node!(trie::Ptrie{K}, addr, new_node::Ptrie{K}) where {K}
    if !isempty(new_node)
        trie.internal_nodes[addr] = new_node
    end
end

function set_internal_node!(trie::Ptrie{K}, addr::Pair, new_node::Ptrie{K}) where {K}
    (first, rest) = addr
    # if haskey(trie.internal_nodes, first)
    #     node = trie.internal_nodes[first]
    # else
    #     node = Ptrie{K}()
    #     trie.internal_nodes[first] = node
    # end
    # Skip to LCA. Then start reading io?
    # set_internal_node!(node, rest, new_node)
end

# function delete_internal_node!(trie::Trie, addr)
#     delete!(trie.internal_nodes, addr)
#     return isempty(trie.leaf_nodes) && isempty(trie.internal_nodes)
# end

# function delete_internal_node!(trie::Trie, addr::Pair)
#     (first, rest) = addr
#     if haskey(trie.internal_nodes, first)
#         node = trie.internal_nodes[first]
#         if delete_internal_node!(node, rest, new_node)
#             delete!(trie.internal_nodes, first)
#         end
#     end
#     return isempty(trie.leaf_nodes) && isempty(trie.internal_nodes)
# end

# function has_leaf_node(trie::Trie, addr)
#     haskey(trie.leaf_nodes, addr)
# end

# function has_leaf_node(trie::Trie, addr::Pair)
#     (first, rest) = addr
#     if haskey(trie.internal_nodes, first)
#         has_leaf_node(trie.internal_nodes[first], rest)
#     else
#         false
#     end
# end

# function get_leaf_node(trie::Trie, addr)
#     trie.leaf_nodes[addr]
# end

# function get_leaf_node(trie::Trie, addr::Pair)
#     (first, rest) = addr
#     if haskey(trie.internal_nodes, first)
#         get_leaf_node(trie.internal_nodes[first], rest)
#     else
#         throw(KeyError(trie, addr))
#     end
# end

function set_leaf_node!(trie::Ptrie{K}, addr, value::RECORD_INFO) where {K}
    trie.leaf_nodes[addr] = value
end

# function set_leaf_node!(trie::Trie{K,V}, addr::Pair, value) where {K,V}
#     (first, rest) = addr
#     if haskey(trie.internal_nodes, first)
#         node = trie.internal_nodes[first]
#     else
#         node = Trie{K,V}()
#         trie.internal_nodes[first] = node
#     end
#     node = trie.internal_nodes[first]
#     set_leaf_node!(node, rest, value)
# end

# function delete_leaf_node!(trie::Trie, addr)
#     delete!(trie.leaf_nodes, addr)
#     return isempty(trie.leaf_nodes) && isempty(trie.internal_nodes)
# end

# function delete_leaf_node!(trie::Trie, addr::Pair)
#     (first, rest) = addr
#     if haskey(trie.internal_nodes[first])
#         node = trie.internal_nodes[first]
#         if delete_leaf_node!(node, rest)
#             delete!(trie.internal_nodes, first)
#         end
#     end
#     return isempty(trie.leaf_nodes) && isempty(trie.internal_nodes)
# end

# function Base.setindex!(trie::Ptrie, addr, value, io) 
# end

# function Base.merge!(a::Trie{K,V}, b::Trie{K,V}) where {K,V}
#     merge!(a.leaf_nodes, b.leaf_nodes)
#     for (key, a_sub) in a.sub
#         if haskey(b.sub, key)
#             b_sub = b.sub[key]
#             merge!(a_sub, b_sub)
#         end
#     end
#     for (key, b_sub) in b.sub
#         if !haskey(a.sub, key)
#             a.sub[key] = b_sub
#         end
#     end
#     a
# end

# get_address_schema(::Trie) = DynamicSchema()

# Base.haskey(trie::Trie, key) = has_leaf_node(trie, key)

# Base.getindex(trie::Trie, key) = get_leaf_node(trie, key)

export Ptrie
# export set_internal_node!
# export delete_internal_node!
# export set_leaf_node!
# export delete_leaf_node!