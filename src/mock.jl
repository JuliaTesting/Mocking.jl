"""
    @mock expr

Allows the call site function to be temporarily overloaded via an applied patch.

The `@mock` macro works as no-op until `Mocking.activate` has been called. Once Mocking has
been activated then alternative methods defined via [`@patch`](@ref) can be used with
[`apply`](@ref) to call the patched methods from within the `apply` context.

See also: [`@patch`](@ref), [`apply`](@ref).

## Examples

```jldoctest; setup=:(using Dates: Dates)
julia> f() = @mock time();

julia> p = @patch time() = 0.0;  # UNIX epoch

julia> apply(p) do
           Dates.unix2datetime(f())
       end
1970-01-01T00:00:00
```
"""
macro mock(expr)
    NULLIFIED[] && return esc(expr)  # Convert `@mock` into a no-op for maximum performace

    isa(expr, Expr) || error("argument is not an expression")
    expr.head == :do && (expr = rewrite_do(expr))
    expr.head == :call || error("expression is not a function call")

    target = expr.args[1]
    args = filter(!iskwarg, expr.args[2:end])
    kwargs = extract_kwargs(expr)

    # Due to how world-age works (see Julia issue #265 and PR #17057) when
    # `Mocking.activated` is overwritten then all dependent functions will be recompiled.
    # When `Mocking.activated() == false` then Julia will optimize the
    # code below to have zero-overhead by only executing the original expression.
    result = quote
        if $activated()
            args_var = tuple($(args...))
            alternate_var = $get_alternate($target, args_var...)
            if alternate_var !== nothing
                Base.invokelatest(alternate_var, args_var...; $(kwargs...))
            else
                $target(args_var...; $(kwargs...))
            end
        else
            $target($(args...); $(kwargs...))
        end
    end

    return esc(result)
end

function get_alternate(pe::PatchEnv, target, args...)
    if haskey(pe.mapping, target)
        m, f = dispatch(pe.mapping[target], args...)

        if pe.debug
            if m !== nothing
                @info _debug_msg(m, target, args)
            else
                target_m, _ = dispatch([target], args...)
                @info _debug_msg(target_m, target, args)
            end
        end

        return f
    else
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
