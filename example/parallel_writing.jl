using Distributed
using FilePathsBase

manager = addprocs(3; exeflags="--project")

# TODO: figure out wtf is going on with @everywhere and loading
# modules.
@everywhere using Gen
@everywhere using GenArrow
@everywhere using LinearAlgebra

@everywhere begin
    # Here, we define a model and a submodel.
    @gen function submodel()
        for k in 1:100
            {:y => k => k} ~ normal(0.0, 1.0)
        end
    end

    @gen function model()
        for k in 1:1000
            {:x => k => k} ~ mvnormal(zeros(100), I(100))
        end
        q ~ submodel()
    end
end

activate(Path("./sample")) do ctx
    # Lambda captures the remote channel here.
    ctx_remote_channel = get_remote_channel(ctx)
    Distributed.pmap([id for id in 1 : nprocs()]) do v
        tr = simulate(model, ())
        GenArrow.write!(ctx.dir, ctx_remote_channel, tr)
    end
end
