module AddressTreeStruct
export AddressTree, InnerNode, TerminalNode

abstract type AddressTree end
mutable struct InnerNode <: AddressTree
    children::Dict
    has_value::Bool
    function InnerNode()
        self = new{}()
        self.has_value = false
        self.children = Dict()
        return self
    end
end
mutable struct TerminalNode{V} <: AddressTree
    val::V
    has_value::Bool
    function TerminalNode(val::V) where {V}
        self = new{V}()
        self.has_value = true
        self.val = val
        return self
    end
end

function Base.setindex!(t::AddressTree, val, key)
    prefix = key
    node = t
    for (i,p) in enumerate(prefix)
        if !haskey(node.children, p)
            if i < length(prefix)
                node.children[p] = InnerNode()
            elseif i == length(prefix)
                node.children[p] = TerminalNode(val)
            end
        end
        node = node.children[p]
    end
    if !node.has_value
        throw(KeyError("Key: $key stores at intermediate node"))
    end
    node.val = val
end

function Base.getindex(t::AddressTree,key)
    node = subtrie(t, key)
    if node != nothing && node.has_value
        return node.val
    end
    throw(KeyError("$key"))
end

function subtrie(node::AddressTree, prefix) # Naive subtrie?
    for p in prefix
        if !node.has_value && haskey(node.children, p)
            node = node.children[p]
        else
            return nothing
        end
    end
    return node
end
end