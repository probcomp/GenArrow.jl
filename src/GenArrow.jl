module GenArrow
using Serialization
using DataFrames
using Gen
using UUIDs
using TOML
using Dates
using Arrow
using ArrowTypes
using FilePathsBase
using Distributed
using Tables
include("./AddressTrie.jl")
using .AddressTreeStruct
include("./GenTable.jl")
using .GenTableStruct

#####
##### exports
###

export activate, write!, get_serializable_args, get_remote_channel

#####
##### Serialization
#####

const MANIFEST_NAME = "TraceManifest.toml"
const CONTEXT_NAME = "Context.toml"

# TODO: possible to make this threadsafe?
# TODO: allow writes to push to a channel.

# Consider making the user write this?
# ArrowTypes.ArrowKind(::Type{Nothing}) = ArrowTypes.NullKind()
# ArrowTypes.ArrowType(::Type{Nothing}) = Missing
# ArrowTypes.toarrow(::Nothing) = missing
# const NOTHING = Symbol("JuliaLang.Nothing")
# ArrowTypes.arrowname(::Type{Nothing}) = NOTHING
# ArrowTypes.JuliaType(::Val{NOTHING}) = Nothing
# ArrowTypes.fromarrow(::Type{Nothing}, ::Missing) = nothing


struct Handler
  dir::AbstractPath
  name::String
  df_buffer::DataFrame
  # lock
end

mutable struct SerializationContext
  dir::AbstractPath
  # manifest::Dict
  # session::Dict
  uuid::UUID
  timestamp::Float64
  datetime::String
  handlers::Dict{String, Handler}
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

# A new interface which users can implement for their `T::Trace`
# type to extract serializable arguments.
function get_serializable_args(tr::T) where {T<:Gen.Trace}
  return Gen.get_args(tr)
end

#####################
# Context Activation
#####################
"""
Creates serialization context at directory dir
"""
function activate(fn::Function, dir::AbstractPath)
  mkpath(dir) 
  @info "(GenArrow) Activating serialization session context in $(dir)"
  ctx = activate(dir)
  # create header file to organize context

  fn(ctx) # Pass context which provides functions to create handlers
  
  ####
  # 1. Clean up file handlers
  # 2. Make sure all directories are referenced in manifest?
  ####

  # Serialize any active data written before the exception was thrown.
  # paths_file = FilePathsBase.join(dir, "$(length(ctx.manifest)).arrow")
  # ctx.session["paths"] = string(paths_file)
  # channel_collection = []
  # while isready(ctx.write_channel)
    # push!(channel_collection, take!(ctx.write_channel))
  # end
  # flat = collect(Iterators.flatten((ctx.write, channel_collection))) # Add back later

  # Write to session_index.arrow file.
  # Arrow.write(paths_file, ctx.write)

  # Write out to the TraceManifest.toml manifest.
  # open(manifest_path, "w") do io
    # TOML.print(io, ctx.manifest; sorted=true)
  # end

  return ctx
end

function activate(dir::AbstractPath)
  # create the header file for the context
  now, dt_now = time(), Dates.now()
  datetime = Dates.format(dt_now, "yyyy-mm-dd HH:MM:SS")
  u4 = uuid4()
  u5 = uuid5(u4, repr(now))
  handlers = Dict{String, Handler}()
  manifest_path = FilePathsBase.join(dir, MANIFEST_NAME)

  # If a manifest already exists, use it.
  if !FilePathsBase.exists(manifest_path)
    TOML.parsefile(string(manifest_path))
  end

    # After parsing, soft verify that it's the correct format.
    # TODO: make this compatible with S3Path.
    # manifest_path = string(manifest_path)
  #   d = TOML.parsefile(manifest_path)
  #   session = Dict{String,Any}("timestamp" => datetime) # Consider separating by run of project?
  #   d["$(repr(length(d) + 1))"] = session


  return SerializationContext(dir, u5, now, datetime, handlers, Any[], RemoteChannel(() -> Channel(Inf)))
end

function create_handler!(ctx::SerializationContext, name::String)
  handler_name = FilePathsBase.join(ctx.dir, name)
  handler = Handler(handler_name, name, DataFrame());
  if !FilePathsBase.exists(handler_name)
    mkdir(handler_name);
  else
    # Throw error indicating handler exists
  end
  # acquire(ctx lock)
  ctx.handlers[name] = handler
  # release (ctx lock)
  return handler
end

function write!(handler::Handler, traces::Vector{<:Gen.Trace}; user_provided_metadata...)
  arrow_file = FilePathsBase.join(handler.dir , "$(uuid4())")
  mkpath(arrow_file)
  save(arrow_file, traces, handler.df_buffer; user_provided_metadata);
  # string_dir = string(arrow_file)
  # push!(ctx, (; path=string_dir, user_provided_metadata...))
  return arrow_file
end

# function write!(ctx::SerializationContext, traces::Vector{<:Gen.Trace}; user_provided_metadata...)
#   dir = FilePathsBase.join(ctx.dir, "$(uuid4())")
#   mkpath(dir)
#   save(dir, traces, ctx.df_buffer; user_provided_metadata)
#   # TODO: Flush ctx.df_buffer?
#   string_dir = string(dir)

#   # Here, we push metadata from successful (we have to replace this
#   # with the channel functionality)
#   push!(ctx, (; path=string_dir, user_provided_metadata...))
#   return dir
# end


function save(dir::AbstractPath, traces::Vector{<:Gen.Trace}, df::DataFrame; user_provided_metadata)
  metadata_path = FilePathsBase.join(dir, "metadata.arrow")
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
    gen_fn = repr(get_gen_fn(tr))
    push!(metadata, (ret=ret, args=args, score=score, gen_fn=gen_fn))
    row, _, _ = traverse(tr, address_trie, address_dict)
    push!(df, row, cols=:union)
  end

  # Flush to arrow?
  args = []
  for meta in metadata
    push!(args, (; args=meta.args))
  end
  Arrow.write(metadata_path, args)
  serialize(string(addrs_trie_path), address_trie)
  serialize(string(addrs_dict_path), address_dict)

  Arrow.write(choices_path, df)
  return address_trie, address_dict, df
end

function save(dir::AbstractPath, tr::Gen.Trace, df::DataFrame; user_provided_metadata)
  # TODO: Implement the single trace version. 
end

function address_to_symbol(addr::Tuple)
  if length(addr) == 1
    return addr[1]
  end
  sym = reduce((addr, y) -> Pair(y, addr), reverse(addr))
end

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

function traverse(tr::Gen.Trace, row, addrs_trie::AddressTree, addrs_dict::Dict)
  leaves = traverse!(get_choices(tr), row, addrs_trie, addrs_dict, tuple(), 1)
  return row, addrs_trie, addrs_dict
end
traverse(tr::Gen.Trace, addrs_trie::AddressTree, addrs_dict::Dict) = traverse(tr, Dict(), addrs_trie, addrs_dict)
traverse(tr::Gen.Trace) = traverse(tr, Dict(), InnerNode(), Dict())

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

end # module
