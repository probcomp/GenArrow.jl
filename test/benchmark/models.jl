using Gen
using LinearAlgebra

@gen function wide(n)
    for i=1:n
        {:k=>i} ~ bernoulli(0.5)
    end
end

@gen function heavy_choice(n)
    a ~ mvnormal(zeros(n), I(n))
end

