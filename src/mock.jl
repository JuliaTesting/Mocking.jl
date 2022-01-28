macro mock(expr)
    NULLIFIED[] && return esc(expr)  # Convert `@mock` into a no-op for maximum performace

    isa(expr, Expr) || error("argument is not an expression")
    expr.head == :do && (expr = rewrite_do(expr))
    expr.head == :call || error("expression is not a function call")

    target = expr.args[1]
    args = filter(!Mocking.iskwarg, expr.args[2:end])
    kwargs = extract_kwargs(expr)

    args_var = gensym("args")
    alternate_var = gensym("alt")

    # Due to how world-age works (see Julia issue #265 and PR #17057) when
    # `Mocking.activated` is overwritten then all dependent functions will be recompiled.
    # When `Mocking.activated() == false` then Julia will optimize the
    # code below to have zero-overhead by only executing the original expression.
    result = quote
        @info "Expanding @mock macro on" $target
        if Mocking.activated()
            @info "Mocking is activated, inserting mocking code"
            local $args_var = tuple($(args...))
            local $alternate_var = Mocking.get_alternate($target, $args_var...)
            if $alternate_var !== nothing
                $alternate_var($args_var...; $(kwargs...))
            else
                $target($args_var...; $(kwargs...))
            end
        else
            @warn "Mocking is NOT activated, running original target"
            $target($(args...); $(kwargs...))
        end
    end

    return esc(result)
end

function get_alternate(pe::PatchEnv, target, args...)
    pe.debug && @info "Looking for target $target in PatchEnv.mapping" keys(pe.mapping)

    if haskey(pe.mapping, target)
        pe.debug && @info "Found target in PatchEnv.mapping. Trying to dispatch for given args:" args "### Available methods:" methods.(pe.mapping[target])
        m, f = dispatch(pe.mapping[target], args...)

        if pe.debug
            if m !== nothing
                @info "Dispatch success"
                @info _debug_msg(m, target, args)
            else
                @info "Dispatch failed for given args, using original target"
                target_m, _ = dispatch([target], args...)
                @info _debug_msg(target_m, target, args)
            end
        end

        return f
    else
        pe.debug && @info "Target not found in PatchEnv.mapping"
        return nothing
    end
end

get_alternate(target, args...) = get_alternate(get_active_env(), target, args...)

function _debug_msg(method::Union{Method,Nothing}, target, args)
    call = "$target($(join(map(arg -> "::$(Core.Typeof(arg))", args), ", ")))"
    return """
        Mocking intercepted:
        call:       $call
        dispatched: $(method === nothing ? "(no matching method)" : method)
        """
end
