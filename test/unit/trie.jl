rec_info = GenArrow.RECORD_INFO

function test_trie_1()
    t = GenArrow.Ptrie{Any}(-1,-1)
    GenArrow.set_leaf_node!(t, :x, rec_info([1,1,true]))
    GenArrow.set_leaf_node!(t, :y, rec_info([1,2,false]))
    leaf_nodes = Dict{Any, rec_info}(:x=>rec_info([1,1,true]), :y=>rec_info([1,2,false]))
    internal_nodes = Dict{Any, Ptrie{Any}}()
    return t.leaf_nodes == leaf_nodes && t.internal_nodes == internal_nodes
end

function test_trie_2()
    t = GenArrow.Ptrie{Any}(-1,-1)
    GenArrow.set_internal_node!(t,:x=>1, 1, 2)
    GenArrow.set_internal_node!(t,:x=>2, 3, 4)
    n1 = t.internal_nodes[:x].internal_nodes[1]
    n2 = t.internal_nodes[:x].internal_nodes[2]

    pass = true
    pass &= length(t.internal_nodes) == 1
    pass &= (n1.ptr == 1) && (n1.length == 2)
    pass &= (n2.ptr == 3) && (n2.length == 4)
    return pass
end

function test_trie_3()
    t = GenArrow.Ptrie{Any}(-1,-1)
    GenArrow.set_internal_node!(t, :x=>:y=>1, 1, 2)
    GenArrow.set_internal_node!(t, :x=>:y, 3, 4) # Requires mutability
    n1 = t.internal_nodes[:x].internal_nodes[:y].internal_nodes[1]
    n2 = t.internal_nodes[:x].internal_nodes[:y]

    pass = true
    pass &= length(t.internal_nodes) == 1
    pass &= length(t.internal_nodes[:x].internal_nodes) == 1
    pass &= (n1.ptr == 1) && (n1.length == 2)
    pass &= (n2.ptr == 3) && (n2.length == 4)
    return pass
end