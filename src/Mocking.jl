module Mocking

include("expr.jl")
include("dispatch.jl")
include("options.jl")

export
    # Mocking.jl
    @patch, @mock, Patch, apply,
    # options.jl
    DISABLE_COMPILED_MODULES_STR, DISABLE_COMPILED_MODULES_CMD

# When ENABLED is false the @mock macro is a noop.
global ENABLED = false
global PATCH_ENV = nothing

function enable(; force::Bool=false)
    ENABLED::Bool && return  # Abend early if enabled has already been set
    global ENABLED = true
    global PATCH_ENV = PatchEnv()

    if compiled_modules_enabled()
        if force
            # Disable using compiled modules when Mocking is enabled
            set_compiled_modules(false)
        else
            @warn(
                "Mocking.jl will probably not work when $COMPILED_MODULES_FLAG is ",
                "enabled. Please start `julia` with `$DISABLE_COMPILED_MODULES_STR` ",
                "or alternatively call `Mocking.enable(force=true).`",
            )
        end
    end
end

# `target` will typically a `Function` or `Type` but could also be a function-like object
struct Patch{T}
    target::T
    alternate::Function
end

macro patch(expr::Expr)
    def = splitdef(expr, throw=false)

    # Expect a named function in long-form or short-form
    if def === nothing
        throw(ArgumentError("expression is not a function definition"))
    elseif def[:type] == :(->)
        throw(ArgumentError("expression needs to be a named function"))
    end

    target_name = def[:name]

    patch_name = if target_name isa Symbol  # f(...)
        target_name
    elseif target_name.head === :.  # Base.f(...)
        target_name.args[2].value
    else
        string(target_name)
    end

    def[:name] = gensym(patch_name)
    alternate_func = combinedef(def)

    # Need to evaluate the patch function in the context of the `@patch` macro in
    # order to support closures.
    return esc(:(Mocking.Patch($target_name, $alternate_func)))
end

struct PatchEnv
    mapping::Dict{Any,Vector{Function}}
    debug::Bool
end

function PatchEnv(patches, debug::Bool=false)
    pe = PatchEnv(debug)
    apply!(pe, patches)
    return pe
end

PatchEnv(debug::Bool=false) = PatchEnv(Dict{Any,Vector{Function}}(), debug)

function apply!(pe::PatchEnv, p::Patch)
    alternate_funcs = get!(Vector{Function}, pe.mapping, p.target)
    push!(alternate_funcs, p.alternate)
    return pe
end

function apply!(pe::PatchEnv, patches)
    for p in patches
        apply!(pe, p)
    end
end

function apply(body::Function, pe::PatchEnv)
    original_pe = get_active_env()
    set_active_env(pe)
    try
        return body()
    finally
        set_active_env(original_pe)
    end
end

function apply(body::Function, patches; debug::Bool=false)
    return apply(body, PatchEnv(patches, debug))
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

set_active_env(pe::PatchEnv) = (global PATCH_ENV = pe)
get_active_env() = PATCH_ENV::PatchEnv

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

include("deprecated.jl")

end # module
