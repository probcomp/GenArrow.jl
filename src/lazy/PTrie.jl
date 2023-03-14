###################
#      PTrie      #
###################

RECORD_INFO = NamedTuple{(:record_ptr, :record_size, :is_trace), Tuple{Int64, Int64, Bool}}
mutable struct PTrie{K, V}
    ptr::Int64
    length::Int64
    leaf_nodes::Dict{K, V} # Invariant: keys are not shared! TODO: Check for this
    internal_nodes::Dict{K,PTrie{K, V}}
end

function PTrie{K, V}(ptr::Int64, length::Int64) where {K,V} 
    if (ptr == -1 && length != -1) || (ptr != -1 && length == -1)
        throw(ArgumentError("Invalid ptr=$(ptr) and length=$(length)"))
    end
    PTrie(ptr, length, Dict{K,V}(), Dict{K,PTrie{K,V}}())
end

# invariant: all internal nodes are nonempty
Base.isempty(trie::PTrie) = (trie.length == -1 && trie.ptr == -1) && isempty(trie.leaf_nodes) && isempty(trie.internal_nodes)
get_leaf_nodes(trie::PTrie) = trie.leaf_nodes
get_internal_nodes(trie::PTrie) = trie.internal_nodes

function set_leaf_node!(trie::PTrie, addr, value)
    if haskey(trie.internal_nodes, addr)
        throw("Addr $(addr) in internal node")
    end
    trie.leaf_nodes[addr] = value
end

function set_leaf_node!(trie::PTrie{K,V}, addr::Pair, value) where {K,V}
    (first, rest) = addr
    if haskey(trie.leaf_nodes, first)
        throw("Intermediate addr $(addr) already in leaf")
    end
    if !haskey(trie.internal_nodes, first)
        set_internal_node!(trie, first, -1, -1)
    end
    set_leaf_node!(trie.internal_nodes[first], rest, value)
end

function set_internal_node!(trie::PTrie{K,V}, addr, new_trie::PTrie{K,V}) where {K,V}
    if haskey(trie.leaf_nodes, addr)
        throw("Leaf prefix of $(addr) already used")
    end
    trie.internal_nodes[addr] = new_trie
end

function set_internal_node!(trie::PTrie{K,V}, addr::Pair, new_trie::PTrie{K,V}) where {K,V}
    (first, rest) = addr
    if haskey(trie.leaf_nodes, first)
        throw("Leaf prefix of $(addr) already used")
    end
    if haskey(trie.internal_nodes, first)
        node = trie.internal_nodes[first]
    else
        node = PTrie{K,V}(-1, -1)
        trie.internal_nodes[first] = node
    end
    set_internal_node!(node, rest, new_trie)
end

set_internal_node!(trie::PTrie{K,V}, addr, ptr, length) where {K,V} = set_internal_node!(trie, addr, PTrie{K,V}(ptr, length))
set_internal_node!(trie::PTrie{K,V}, addr::Pair, ptr, length) where {K,V} = set_internal_node!(trie, addr, PTrie{K,V}(ptr, length))

function update_internal_node!(trie::PTrie, addr, ptr, length)
    node = get_internal_node(trie, addr)
    node.ptr = ptr
    node.length = length
    node
end

function get_internal_node(trie::PTrie, addr::Pair)
    (first, rest) = addr
    get_internal_node(trie.internal_nodes[first], rest)
end

get_internal_node(trie::PTrie, addr) = trie.internal_nodes[addr]

has_internal_node(trie::PTrie, addr) = haskey(trie.internal_nodes, addr)

function has_internal_node(trie::PTrie, addr::Pair) 
    (first, rest) = addr
    if !haskey(trie.internal_nodes, first)
        return false
    end
    has_internal_node(trie.internal_nodes[first], rest)
end

function has_leaf_node(trie::PTrie, addr::Pair)
    (first, rest) = addr
    if !haskey(trie.internal_nodes, first)
        return false
    end
    has_leaf_node(trie, rest)
end

has_leaf_node(trie::PTrie, addr) = haskey(trie.leaf_nodes, addr)

# get_address_schema(::Trie) = DynamicSchema()

Base.haskey(trie::PTrie, key) = has_leaf_node(trie, key)

Base.getindex(trie::PTrie, key) = get_leaf_node(trie, key)

function Base.show(io::IO, trie::PTrie{K, V}) where {K, V} 
    show(io, trie, Int[])
end
function Base.show(io::IO, trie::PTrie{K, V}, shift::Vector{Int}) where {K, V}
    if length(shift) == 0
        tab = " "
    else
        tab = " "
        for s in shift
            tab *= "┃" * repeat(" ", s-1)
        end
    end
    println(io, tab[1:end-1] * "Ptr: $(trie.ptr), Length: $(trie.length)")
    println(io, tab[1:end-1] * "[L]")
    for (key, val) in trie.leaf_nodes
        println(io,  tab * "┣━━ $(key) ━ $(val)")
    end
    println(io, tab[1:end-1] * "[I]")

    for (key, subtrie) in trie.internal_nodes
        key_prefix = "┣━━ $(key) ━┓"
        new_shift = vcat(shift, [length(key_prefix)])
        key_prefix = tab * key_prefix 
        println(io, key_prefix)
        show(io, subtrie, new_shift)
    end
end

# export PTrie
# export set_internal_node!
# export delete_internal_node!
# export set_leaf_node!
# export delete_leaf_node!
