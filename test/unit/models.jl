@gen function leaves(n)
    x ~ bernoulli(0.5)
    y ~ submodel(n)
end

@gen function submodel(n)
    for i=1:n
        @trace(normal(0.0, 1), i)
    end
    -n
end

@gen function internal(n)
    for i=1:n
        {:k=>i} ~ bernoulli(0.5)
    end
end

@gen function mixed(n)
    a ~ normal(0.0, 1)
    b ~ submodel(n)
    for i=1:n
        {:k=>i} ~ bernoulli(0.5)
        {:q=>i} ~ submodel(n)
    end
end

@gen function dist_with_untraced_arg()
    p = rand()
    a ~ bernoulli(p)
    p
end

@gen function subtrace_with_untraced_arg()
    n = rand(1:4)
    a ~ submodel(n)
    n
end