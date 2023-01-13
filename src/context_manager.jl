using UUIDs
using TOML
using Dates
using Distributed

#####
##### exports
#####

export activate, write!, get_serializable_args, get_remote_channel

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
  # lock::
end

mutable struct SerializationContext
  dir::AbstractPath
  header::AbstractPath
  # manifest::Dict
  # session::Dict
  uuid::UUID
  timestamp::Float64
  datetime::String
  handlers::Dict{String, Handler}
  write::Vector
  write_channel::RemoteChannel
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
  header = FilePathsBase.join(dir, CONTEXT_NAME)

  if !FilePathsBase.exists(header)
    open(header, "w") do io
    end
  end

  return SerializationContext(dir, header, u5, now, datetime, handlers, Any[], RemoteChannel(() -> Channel(Inf)))
end

function create_handler!(ctx::SerializationContext, name::String)
  handler_name = FilePathsBase.join(ctx.dir, name)
  handler = Handler(handler_name, name);
  if !FilePathsBase.exists(handler_name)
    mkdir(handler_name);
  else
    # Throw error indicating handler exists
  end
  # acquire(ctx lock)
  context_toml = TOML.parsefile(string(ctx.header))
  context_toml[name] = "info"
  # #   session = Dict{String,Any}("timestamp" => datetime) # Consider separating by run of project?
  # #   d["$(repr(length(d) + 1))"] = session
  open(ctx.header, "w") do io 
    TOML.print(io, context_toml)
  end

  ctx.handlers[name] = handler
  # release (ctx lock)
  return handler
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


import Base: push!
function Base.push!(ctx::SerializationContext, metadata::NamedTuple)
  push!(ctx.write, metadata)
end

function get_remote_channel(ctx::SerializationContext)
  return ctx.write_channel
end