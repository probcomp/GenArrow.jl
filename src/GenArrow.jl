module GenArrow
using Gen
using UUIDs
using TOML
using Dates
using Arrow
using ArrowTypes
using FilePathsBase
using Distributed

#####
##### exports
#####

export activate, write!, address_filter, get_serializable_args, get_remote_channel

#####
##### Serialization
#####

# A new interface which users can implement for their `T::Trace`
# type to extract serializable arguments.
function get_serializable_args(tr::T) where {T<:Gen.Trace}
  return Gen.get_args(tr)
end


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
  typeset = Set(Type[]) # Collect all the types seen?
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

function traverse(tr::Gen.Trace)
  ret = get_retval(tr)
  args = get_serializable_args(tr)
  score = get_score(tr)
  gen_fn = repr(get_gen_fn(tr))
  addrs, choices = traverse(get_choices(tr))
  metadata = (; gen_fn, score, ret, args)
  return metadata, addrs, choices
end

function save(dir::AbstractPath, tr::Gen.Trace; user_provided_metadata)
  metadata, addrs, choices = traverse(tr)
  metadata_path = FilePathsBase.join(dir, "metadata.arrow")
  addrs_path = FilePathsBase.join(dir, "addrs.arrow")
  choices_path = FilePathsBase.join(dir, "choices.arrow")
  x = (; user_provided_metadata...)
  tbl = merge(metadata, x)
  Arrow.write(metadata_path, [tbl])
  Arrow.write(addrs_path, map(addrs) do addr
    (; addr=collect(addr))
  end)
  Arrow.write(choices_path, choices)
  return dir
end

#####
##### Serialization target directory management
#####

const MANIFEST_NAME = "TraceManifest.toml"

# TODO: possible to make this threadsafe?
# TODO: allow writes to push to a channel.

mutable struct SerializationContext
  dir::AbstractPath
  manifest::Dict
  session::Dict
  uuid::UUID
  timestamp::Float64
  datetime::String
  write::Vector
  write_channel::RemoteChannel
end

import Base: push!
function Base.push!(ctx::SerializationContext, metadata::NamedTuple)
  push!(ctx.write, metadata)
end

function get_remote_channel(ctx::SerializationContext)
  return ctx.write_channel
end

function activate(dir::AbstractPath)
  @info "(GenArrow) Activating serialization session context in $(dir)"
  now, dt_now = time(), Dates.now()
  datetime = Dates.format(dt_now, "yyyy-mm-dd HH:MM:SS")
  u4 = uuid4()
  u5 = uuid5(u4, repr(now))
  manifest_path = FilePathsBase.join(dir, MANIFEST_NAME)

  # If a manifest already exists, use it.
  if FilePathsBase.exists(manifest_path)

    # After parsing, soft verify that it's the correct format.
    # TODO: make this compatible with S3Path.
    manifest_path = string(manifest_path)
    d = TOML.parsefile(manifest_path)
    session = Dict{String,Any}("timestamp" => datetime)
    d["$(repr(length(d) + 1))"] = session

    # If it doesn't exist, make it.
  else
    d = Dict()
    session = Dict{String,Any}("timestamp" => datetime)
    d["$(repr(1))"] = session
  end

  return SerializationContext(dir, d, session, u5, now, datetime, Any[], RemoteChannel(() -> Channel(Inf)))
end

function write!(ctx::SerializationContext, tr::Gen.Trace; user_provided_metadata...)
  dir = FilePathsBase.join(ctx.dir, "$(uuid4())")
  mkpath(dir)
  save(dir, tr; user_provided_metadata)
  string_dir = string(dir)

  # Here, we push metadata from successful (we have to replace this
  # with the channel functionality)
  push!(ctx, (; path=string_dir, user_provided_metadata...))
end

function write!(dir::AbstractPath, ctx_remote_channel::RemoteChannel, tr::Gen.Trace;
  user_provided_metadata...)
  dir = FilePathsBase.join(dir, "$(uuid4())")
  mkpath(dir)
  save(dir, tr; user_provided_metadata)
  string_dir = string(dir)

  # Here, we push metadata from successful (we have to replace this
  # with the channel functionality)
  Base.put!(ctx_remote_channel, (; path=string_dir, user_provided_metadata...))
end

function write_session_metadata!(ctx::SerializationContext, metadata::Dict)
  ctx.session
  haskey(metadata, "paths") && error("Metadata dictionary provided to `write_session_metadata!` must not contain a `paths` key.")
  haskey(metadata, "timestamp") && error("Metadata dictionary provided to `write_session_metadata!` must not contain a `timestamp` key.")
  merge!(ctx.session, metadata)
end

function activate(fn::Function, dir::AbstractPath)
  mkpath(dir)
  ctx = activate(dir)
  manifest_path = FilePathsBase.join(dir, MANIFEST_NAME)

  # Try to run the function.
  caught = try
    fn(ctx)
    nothing
  catch e
    e
  end

  # Serialize any active data written before the exception was thrown.
  paths_file = FilePathsBase.join(dir, "$(length(ctx.manifest)).arrow")
  ctx.session["paths"] = string(paths_file)
  channel_collection = []
  while isready(ctx.write_channel)
    push!(channel_collection, take!(ctx.write_channel))
  end
  flat = collect(Iterators.flatten((ctx.write, channel_collection)))

  # Write to session_index.arrow file.
  open(paths_file, "w") do io
    Arrow.write(io, (trace_directory=flat,))
  end

  # Write out to the TraceManifest.toml manifest.
  open(manifest_path, "w") do io
    TOML.print(io, ctx.manifest; sorted=true)
  end

  # If caught is not nothing (e.g. an exception), rethrow.
  # caught != nothing && rethrow(caught)

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
      addrs_path = FilePathsBase.join(p, "addrs.arrow")
      tbl = Arrow.Table(Arrow.read(addrs_path))
      fn(map(tbl.addr) do v
        foldr(Pair, map(str_to_symbol, v))
      end)
    end
  end)
end

end # module
