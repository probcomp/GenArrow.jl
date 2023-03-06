using Gen
using LinearAlgebra

@gen function gen_1(N)
  mu = zeros(5)
  cov = I(5)
  for k in 1:N
    {:r => k} ~ mvnormal(mu, cov)
  end
end

@gen function gen_2(branch)

end

# abstract type Node end

# struct InternalNode <: Node
#   left::Node
#   right::Node
#   interval::Interval
# end

# struct LeafNode <: Node
#   value::Float64
#   interval::Interval
# end
# @gen function gen_3(l::Float64, u::Float64)
#   interval = Interval(l, u)
#   if ({:isleaf} ~ bernoulli(0.6))
#     value = ({:value} ~ normal(0, 1))
#     return LeafNode(value, interval)
#   else
#     frac = ({:frac} ~ beta(2, 2))
#     mid = l + (u - l) * frac
#     # Call generate_segments recursively!
#     # Because we will call it twice -- one for the left 
#     # child and one for the right child -- we use
#     # addresses to distinguish the calls.
#     left = ({:left} ~ generate_segments(l, mid))
#     right = ({:right} ~ generate_segments(mid, u))
#     return InternalNode(left, right, interval)
#   end
# end
