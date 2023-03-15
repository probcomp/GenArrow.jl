using Gen
using GenArrow
using Test
using Serialization

include("tools.jl")
include("models.jl")
include("heavy.jl")
include("lazy.jl")

# Heavy 
@test test_leaves()
@test test_internal()
@test test_mixed()
@test (@untraced test_dist_with_untraced_arg 100)()
@test (@untraced test_subtrace_with_untraced_arg 100)()
@test (@untraced test_untraced_mixed 100)()

# Lazy
@test test_lazy_basic()
@test test_lazy_leaves()
@test test_lazy_internal()
@test test_lazy_mixed()
@test (@untraced test_lazy_dist_with_untraced_arg 100)()
@test (@untraced test_lazy_subtrace_with_untraced_arg 100)()
@test (@untraced test_lazy_untraced_mixed 100)()