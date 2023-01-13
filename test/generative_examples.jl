using Gen
using LinearAlgebra

@gen function gen_1(N)
  mu = zeros(5)
  cov = I(5)
  for k in 1:N
    {:r => k} ~ mvnormal(mu, cov)
  end
end
