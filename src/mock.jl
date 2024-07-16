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

    call_loc = sprint(_print_module_path_file, __module__, __source__)

    # Due to how world-age works (see Julia issue #265 and PR #17057) when
    # `Mocking.activated` is overwritten then all dependent functions will be recompiled.
    # When `Mocking.activated() == false` then Julia will optimize the
    # code below to have zero-overhead by only executing the original expression.
    result = quote
        if $activated()
            args_var = tuple($(args...))
            alternate_var = $get_alternate($target, args_var...; call_loc=$call_loc)
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

function get_alternate(pe::PatchEnv, target, args...; call_loc)
    if haskey(pe.mapping, target)
        m, f = dispatch(pe.mapping[target], args...)

        @debug begin
            call_site = _call_site(target, args, call_loc)
            if m !== nothing
                _intercepted_msg(call_site, m, "Patch called")
            else
                target_m, _ = dispatch([target], args...)
                _intercepted_msg(call_site, target_m, "No patch handles provided arguments")
            end
        end _file = nothing _line = nothing

        return f
    else
        @debug begin
            call_site = _call_site(target, args, call_loc)
            target_m, _ = dispatch([target], args...)
            _intercepted_msg(call_site, target_m, "No patch defined for target function")
        end _file = nothing _line = nothing

        return nothing
    end
end

function get_alternate(target, args...; kwargs...)
    return get_alternate(get_active_env(), target, args...; kwargs...)
end

function _intercepted_msg(
    call_site::AbstractString, method::Union{Method,Nothing}, reason::AbstractString
)
    return """
        Mocking intercepted:
        call site:  $call_site
        dispatched: $(method === nothing ? "(no matching method)" : method)
        reason:     $reason
        """
end

function _call_site(target, args, location)
    call = "$target($(join(map(arg -> "::$(Core.Typeof(arg))", args), ", ")))"
    return "$call $location"
end

# Mirroring the print format used when showing a method. Based upon the function
# `Base.print_module_path_file` which was introduced in Julia 1.10.
if VERSION >= v"1.9"
    function _print_module_path_file(io::IO, modul, file::AbstractString, line::Integer)
        print(io, "@")

        # module
        modul !== nothing && print(io, " ", modul)

        # filename, separator, line
        file = contractuser(file)
        print(io, " ", file, ":", line)
    end
else
    function _print_module_path_file(io::IO, modul, file::AbstractString, line::Integer)
        print(io, "in")

        # module
        modul !== nothing && print(io, " ", modul, " at")

        # filename, separator, line
        print(io, " ", file, ":", line)
    end
end

function _print_module_path_file(io::IO, modul, source::LineNumberNode)
    return _print_module_path_file(io, modul, string(source.file), source.line)
end
