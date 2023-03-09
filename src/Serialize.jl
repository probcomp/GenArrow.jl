function write!(handler::Handler, trace::Gen.Trace, file::String)
    arrow_file = FilePathsBase.join(handler.dir, file)
    mkpath(arrow_file)
    save(arrow_file, [trace], DataFrame();) # BAD
    return arrow_file
end

function write!(handler::Handler, trace::Gen.Trace)
    write!(handler, trace, "$(uuid4())")
end

function write!(handler::Handler, traces::Vector{<:Gen.Trace})
    # TODO: Use write! and pass arrow_file
    write!(handler, traces, "$(uuid4())")
end

function write!(handler::Handler, traces::Vector{<:Gen.Trace}, name::String)
    arrow_file = FilePathsBase.join(handler.dir, name)
    mkpath(arrow_file)
    save(arrow_file, traces, DataFrame()) # TODO: Fix buffer
    # string_dir = string(arrow_file)
    # push!(ctx, (; path=string_dir, user_provided_metadata...))
    return arrow_file
end

# A new interface which users can implement for their `T::Trace`
# type to extract serializable arguments.
function get_serializable_args(tr::T) where {T<:Gen.Trace}
    return Gen.get_args(tr)
end

# function save(dir::AbstractPath, tr::Gen.Trace, df::DataFrame; user_provided_metadata)
#   # TODO: Implement the single trace version. 
# end

# TODO: Move to Serialize.jl
function save(dir::AbstractPath, traces::Vector{<:Gen.Trace}, df::DataFrame)
    metadata_path = FilePathsBase.join(dir, "metadata.arrow") #
    addrs_trie_path = FilePathsBase.join(dir, "addrs_trie.jls")
    addrs_dict_path = FilePathsBase.join(dir, "addrs_dict.jls")
    choices_path = FilePathsBase.join(dir, "choices.arrow")

    # Construct super-trie and populate df
    metadata = []
    address_trie = InnerNode()
    address_dict = Dict()
    # Metadata arrow table contains ret, args, score, gen_fn, user_provided_metadata
    for tr in traces
        ret = get_retval(tr)
        args = get_serializable_args(tr)
        score = get_score(tr)
        # gen_fn = repr(get_gen_fn(tr))
        push!(metadata, (ret=ret, args=args, score=score))
        row, _, _ = traverse(tr, address_trie, address_dict) # 
        push!(df, row, cols=:union)
    end

    # Flush to arrow?
    args = []
    for meta in metadata
        push!(args, (; args=meta.args))
    end
    Arrow.write(metadata_path, args) #
    serialize(string(addrs_trie_path), address_trie) # 
    serialize(string(addrs_dict_path), address_dict)

    Arrow.write(choices_path, df)  # 
    return address_trie, address_dict, df
end

# TODO: Move to Serialize.jl
function address_to_symbol(addr::Tuple)
    if length(addr) == 1
        return addr[1]
    end
    sym = reduce((addr, y) -> Pair(y, addr), reverse(addr))
end

# TODO: Move to Serialize.jl
function traverse!(chm::Gen.ChoiceMap, row, addrs_trie::AddressTree, addrs_dict::Dict, prefix::Tuple, count::Int)
    for (k, v) in get_values_shallow(chm)
        addr = (prefix..., k)
        key = address_to_symbol(addr) # TODO: Address speed of this
        row[Symbol(key)] = v
        if !haskey(addrs_dict, key)
            addrs_dict[key] = count
            addrs_trie[addr] = count
        end
        count += 1

    end

    for (k, subchm) in get_submaps_shallow(chm)
        count = traverse!(subchm, row, addrs_trie, addrs_dict, (prefix..., k), count)
    end
    return count
end

# TODO: Move to Serialize.jl
function traverse(tr::Gen.Trace, row, addrs_trie::AddressTree, addrs_dict::Dict)
    leaves = traverse!(get_choices(tr), row, addrs_trie, addrs_dict, tuple(), 1)
    return row, addrs_trie, addrs_dict
end
traverse(tr::Gen.Trace, addrs_trie::AddressTree, addrs_dict::Dict) = traverse(tr, Dict(), addrs_trie, addrs_dict)
traverse(tr::Gen.Trace) = traverse(tr, Dict(), InnerNode(), Dict())

# TODO: Move to Serialize.jl
function view(dir::AbstractPath; metadata=true)
    paths = Arrow.Table(dir)[:path]
    dir = Path(paths[1]) # TODO: Handle multiple writes.
    choices_path = FilePathsBase.join(dir, "choices.arrow")
    addrs_trie = deserialize("$(dir)/addrs_trie.jls")
    addrs_dict = deserialize("$(dir)/addrs_dict.jls")
    if metadata # TODO: This is temporary for application debugging
        metadata_path = FilePathsBase.join(dir, "metadata.arrow")
        return GenTable(Arrow.Table(metadata_path), Arrow.Table(choices_path), addrs_trie, addrs_dict) # Use address dictionary for type?
    else
        return GenTable(nothing, Arrow.Table(choices_path), addrs_trie, addrs_dict)
    end
end

# TODO: Move to Serialize.jl
function reconstruct_trace(gen_fn, gentable::GenTable, index::Int) # TODO: Slow. Uses strings as symbols
    df = DataFrame(gentable.choice_table)[index, :]
    columns = names(df)
    mappings = []
    for col in columns
        if !isequal(df[col], missing)
            push!(mappings, (eval(Meta.parse(col)), df[col]))
        end
    end
    args = DataFrame(gentable.metadata_table)[index, 1]
    chm = choicemap(mappings...)
    Gen.generate(gen_fn, args, chm)
end

function reconstruct_trace(gen_fn, choice_map_table::Arrow.Table, metadata_table)
    df = DataFrame(choice_map_table)[1, :]
    columns = names(df)
    mappings = []
    for col in columns
        if !isequal(df[col], missing)
            push!(mappings, (eval(Meta.parse(col)), df[col]))
        end
    end
    args = DataFrame(metadata_table)[1, 1]
    chm = choicemap(mappings...)
    Gen.generate(gen_fn, args, chm)
end

"""
Minimal convenience function to read one trace
"""
function deserialize(gen_fn, filename::AbstractPath)
    choice_map_path = string(FilePathsBase.join(filename, "choices.arrow"))
    metadata_path = string(FilePathsBase.join(filename, "metadata.arrow"))
    # addrs_trie_path = string(FilePathsBase.join(filename, "addrs_trie.jls"))
    # addrs_dict_path = string(FilePathsBase.join(filename, "addrs_dict.jls"))

    choice_map_table = Arrow.Table(choice_map_path)
    # addrs_trie = Serialization.deserialize(addrs_trie_path)
    # addrs_dict = Serialization.deserialize(addrs_dict_path)
    metadata = Arrow.Table(metadata_path)
    return reconstruct_trace(gen_fn, choice_map_table, metadata)
end
