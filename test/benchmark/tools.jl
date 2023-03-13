function exp_scale(start, phi, N)
    [ceil(Int64, start * (phi^i)) for i in 1:N]
end

function setup(tr)
  io = IOBuffer()
  serialize(io, tr)
  io
end

function setup(gen_fn, io::IO)
  seekstart(io)
  _deserialize(gen_fn, io)
end

function serialize_benchmark(gen_fn, args)
    tr, _ = generate(gen_fn, args)
    bench = @bprofile setup($(tr))
    prof = Profile.fetch()
    bench, prof
end

function deserialize_benchmark(gen_fn, args)
    io = IOBuffer()
    tr, _ = generate(gen_fn, args)
    serialize(io, tr)
    bench = @bprofile setup($(gen_fn), $(io))
    prof = Profile.fetch()
    bench, prof
end