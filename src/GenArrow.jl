module GenArrow

using Gen
using UUIDs
using TOML
using Dates
using Arrow
using ArrowTypes

#####
##### exports
#####

export activate, write!, address_filter

#####
##### Serialization
#####

# This is a zero-cost immutable reference to data of type `T`.
struct ZeroCost{T}
    data::T
end

function unbox(zc::ZeroCost{T}) where {T}
    return zc.data
end

function traverse!(flat::Vector, typeset::Set, par::Tuple, chm::Gen.ChoiceMap)
    for (k, v) in get_values_shallow(chm)
        push!(typeset, typeof(v))
        push!(flat, ((par..., k), ZeroCost(v)))
    end

    for (p, sub) in get_submaps_shallow(chm)
        traverse!(flat, typeset, (par..., p), sub)
    end
end

function second(x)
    return x[2]
end

function traverse(chm::Gen.ChoiceMap)
    typeset = Set(Type[])
    flat = Tuple{Any,ZeroCost}[]
    for (k, v) in get_values_shallow(chm)
        push!(typeset, typeof(v))
        push!(flat, ((k,), ZeroCost(v)))
    end
    for (par, sub) in get_submaps_shallow(chm)
        traverse!(flat, typeset, (par,), sub)
    end
    ts = collect(typeset)
    addrs = map(first, flat)
    vs = map(second, flat)
    sparse = map(vs) do v
        v = unbox(v)
        (; (typeof(v) <: t ? Symbol(t) => v : Symbol(t) => missing for t in ts)...)
    end
    return addrs, sparse
end

function traverse(tr::Gen.Trace; user_provided_metadata...)
    ret = get_retval(tr)
    args = get_args(tr)
    score = get_score(tr)
    gen_fn = repr(get_gen_fn(tr))
    addrs, choices = traverse(get_choices(tr))
    metadata = (; gen_fn, score, ret, args, user_provided_metadata...)
    return metadata, addrs, choices
end

function save(dir, tr::Gen.Trace; user_provided_metadata...)
    mkpath(dir)
    metadata, addrs, choices = traverse(tr; user_provided_metadata...)
    metadata_path = joinpath(dir, "metadata.arrow")
    addrs_path = joinpath(dir, "addrs.arrow")
    choices_path = joinpath(dir, "choices.arrow")
    Arrow.write(metadata_path, [metadata])
    Arrow.write(addrs_path, map(addrs) do addr
        (; addr=collect(addr))
    end)
    Arrow.write(choices_path, choices)
    return dir
end

#####
##### Serialization target directory management
#####

const manifest_name = "TraceManifest.toml"

# TODO: possible to make this threadsafe?
# TODO: allow writes to push to a channel.

struct SerializationContext
    dir
    manifest::Dict
    entry::Dict
    uuid::UUID
    timestamp::Float64
    datetime::String
    written_paths::Vector
end

import Base: push!
function Base.push!(ctx::SerializationContext, path)
    datetime = ctx.datetime
    entry = ctx.entry
    push!(entry["paths"], path)
    push!(ctx.written_paths, path)
end

function activate(dir)
    now, dt_now = time(), Dates.now()
    datetime = Dates.format(dt_now, "yyyy-mm-dd HH:MM:SS")
    u4 = uuid4()
    u5 = uuid5(u4, repr(now))
    try
        d = TOML.parsefile(joinpath(dir, manifest_name))
        entry = Dict(
            "timestamp" => datetime,
            "paths" => String[])
        d[repr(length(d) + 1)] = entry
        return SerializationContext(dir, d, entry, u5, now, datetime, [])
    catch e
        d = Dict()
        entry = Dict(
            "timestamp" => datetime,
            "paths" => String[])
        d[repr(1)] = entry
        return SerializationContext(dir, d, entry, u5, now, datetime, [])
    end
end

function write!(ctx::SerializationContext, tr::Gen.Trace;
    user_provided_metadata...)
    dir = joinpath(ctx.dir, "$(uuid4())")
    save(dir, tr; user_provided_metadata...)
    push!(ctx, dir)
end

function activate(fn, dir)
    ctx = activate(dir)
    fn(ctx)
    manifest_path = joinpath(dir, manifest_name)
    open(manifest_path, "w") do io
        TOML.print(io, ctx.manifest; sorted=true)
    end
    return ctx
end

#####
##### Query interface
#####

function str_to_symbol(s::String)
    return Symbol(s)
end

function str_to_symbol(s)
    return s
end

function address_filter(fn::Function, ctx::SerializationContext)
    manifest = collect(ctx.manifest)
    Iterators.flatten(map(manifest) do (k, v)
        paths = v["paths"]
        filter(paths) do p
            addrs_path = joinpath(p, "addrs.arrow")
            tbl = Arrow.Table(Arrow.read(addrs_path))
            fn(map(tbl.addr) do v
                foldr(Pair, map(str_to_symbol, v))
            end)
        end
    end)
end

end # module
