macro mock(expr)
    isa(expr, Expr) || error("argument is not an expression")
    expr.head == :do && (expr = rewrite_do(expr))
    expr.head == :call || error("expression is not a function call")
    ENABLED::Bool || return esc(expr)  # @mock is a no-op when Mocking is not ENABLED

    target = expr.args[1]
    args = filter(!Mocking.iskwarg, expr.args[2:end])
    kwargs = extract_kwargs(expr)

    args_var = gensym("args")
    alternate_var = gensym("alt")

    # Note: The fix to Julia issue #265 (PR #17057) introduced changes where no compiled
    # calls could be made to functions compiled afterwards. Since the `Mocking.apply`
    # do-block syntax compiles the body of the do-block function before evaluating the
    # "outer" function this means our patch functions will be compiled after the "inner"
    # function.
    result = quote
        local $args_var = tuple($(args...))
        local $alternate_var = Mocking.get_alternate($target, $args_var...)
        if $alternate_var !== nothing
            Base.invokelatest($alternate_var, $args_var...; $(kwargs...))
        else
            $target($args_var...; $(kwargs...))
        end
    end

    return esc(result)
end

function get_alternate(pe::PatchEnv, target, args...)
    if haskey(pe.mapping, target)
        m, f = dispatch(pe.mapping[target], args...)

        if pe.debug
            @info "calling mocked method: $m"
        end

        return f
    else
        if pe.debug
            m, f = dispatch([target], args...)  # just looking up `m` for logging purposes
            @info "calling original method: $m"
        end

        return nothing
    end
end

get_alternate(target, args...) = get_alternate(get_active_env(), target, args...)
