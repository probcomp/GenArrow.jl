macro untraced(test, trials)
    expr = quote
        function untraced_what()
            valid = true
            for i in 1:$(trials)
                valid &= $(test)()
            end
            return valid
        end
    end
    eval(expr)
end

function observational_equality(tr1, tr2)
    if (get_score(tr1) != get_score(tr2))
        println("Wrong scores tr1: $(get_score(tr1)), tr2: $(get_score(tr2))")
        return false
    end
    if (get_args(tr1) != get_args(tr2))
        println("Wrong args tr1: $(get_args(tr1)), tr2: $(get_args(tr2))")
        return false
    end
    if (get_retval(tr1) != get_retval(tr2))
        println("Wrong retval tr1: $(get_retval(tr1)), tr2: $(get_retval(tr2))")
        return false
    end
    if (get_choices(tr1) != get_choices(tr2))
        println("Wrong choices")
        display(get_choices(tr1))
        display(get_choices(tr))
        return false
    end
    return true
end

function write_to_file(fname, input)
    seekstart(input)
    data = read(input, String)
    open(fname, "w") do io
        write(io, data)
    end
end
