module GenArrow

using Gen
using Arrow

function traverse!(flat::Vector, par::Tuple, chm::Gen.ChoiceMap)
    for (k, v) in get_values_shallow(chm)
        push!(flat, ((par..., k), v))
    end

    for (p, sub) in get_submaps_shallow(chm)
        traverse!(flat, (par..., p), sub)
    end
end

second(x) = x[2]

function traverse(chm::Gen.ChoiceMap)
    flat = []
    for (k, v) in get_values_shallow(chm)
        push!(flat, ((k,), v))
    end
    for (par, sub) in get_submaps_shallow(chm)
        traverse!(flat, (par,), sub)
    end
    return (map(first, flat), map(second, flat))
end

function traverse(tr::Gen.Trace)
    ret = get_retval(tr)
    args = get_args(tr)
    score = get_score(tr)
    addrs, vals = traverse(get_choices(tr))
    return (; score, ret, args, addrs, map(enumerate(vals)) do (ind, v)
        Symbol(ind) => v
    end...)
end

import Arrow: write
function Arrow.write(io, tr::Gen.Trace)
    walked = traverse(tr)
    Arrow.write(io, [walked])
end

struct PartialTrace
    args::Tuple
    ret::Any
    choices::Gen.ChoiceMap
    score::Float64
end

function deserialize(io)
    tbl = Arrow.Table(Arrow.read(io))
    chm = choicemap(map(enumerate(keys(tbl)[5:end])) do (ind, k)
        addr = tbl.addrs[1][ind]
        val = tbl[k][1]
        (addr, val)
    end...)
    PartialTrace(tbl.args[1], tbl.ret[1], chm, tbl.score[1])
end

end # module
