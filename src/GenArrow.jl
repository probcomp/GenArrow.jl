module GenArrow

using Gen
using Arrow
using ArrowTypes

function traverse!(flat::Vector, typeset::Set, par::Tuple, chm::Gen.ChoiceMap)
    for (k, v) in get_values_shallow(chm)
        push!(typeset, typeof(v))
        push!(flat, ((par..., k), v))
    end

    for (p, sub) in get_submaps_shallow(chm)
        traverse!(flat, typeset, (par..., p), sub)
    end
end

second(x) = x[2]

function traverse(chm::Gen.ChoiceMap)
    typeset = Set(Type[])
    flat = []
    for (k, v) in get_values_shallow(chm)
        push!(typeset, typeof(v))
        push!(flat, ((k,), v))
    end
    for (par, sub) in get_submaps_shallow(chm)
        traverse!(flat, typeset, (par,), sub)
    end
    ts = collect(typeset)
    addrs = map(first, flat)
    vs = map(second, flat)
    sparse = map(zip(addrs, vs)) do (addr, v)
        (; [typeof(v) == t ? Symbol(t) => v : Symbol(t) => missing for t in ts]...)
    end
    return addrs, sparse
end

function traverse(tr::Gen.Trace)
    ret = get_retval(tr)
    args = get_args(tr)
    score = get_score(tr)
    addrs, sparse_choices = traverse(get_choices(tr))
    metadata = (; score, ret, args)
    return metadata, addrs, sparse_choices
end

function serialize(dir, tr::Gen.Trace)
    mkpath(dir)
    metadata, addrs, sparse_choices = traverse(tr)
    metadata_path = joinpath(dir, "inference_metadata.arrow")
    addrs_path = joinpath(dir, "addrs.arrow")
    choices_path = joinpath(dir, "sparse_choices.arrow")
    Arrow.write(metadata_path, [metadata])
    Arrow.write(addrs_path, map(addrs) do addr
        (; addr=collect(addr))
    end)
    Arrow.write(choices_path, sparse_choices)
end

end # module
