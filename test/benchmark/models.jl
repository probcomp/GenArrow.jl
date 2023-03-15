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

@gen function stalling(n)
    for i=1:n
        {:a=>i} ~ mvnormal(zeros(3), I(3))
    end
    return 1
end

