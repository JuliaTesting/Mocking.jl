__precompile__(true)

module Mocking

import Compat: invokelatest

include("expr.jl")
include("bindings.jl")

export @patch, @mock, Patch, apply, DISABLE_PRECOMPILE_STR, DISABLE_PRECOMPILE_CMD

# When ENABLED is false the @mock macro is a noop.
global ENABLED = false
global PATCH_ENV = nothing

const PRECOMPILE_FLAG = if VERSION >= v"0.7.0-DEV.1698"
    Symbol("compiled-modules")
elseif VERSION >= v"0.5.0-dev+977"
    :compilecache
else
    Symbol()
end

const PRECOMPILE_FIELD = if VERSION >= v"0.7.0-DEV.1698"
    :use_compiled_modules
elseif VERSION >= v"0.5.0-dev+977"
    :use_compilecache
else
    Symbol()
end

const DISABLE_PRECOMPILE_STR = PRECOMPILE_FLAG == Symbol() ? "" : "--$PRECOMPILE_FLAG=no"
const DISABLE_PRECOMPILE_CMD = isempty(DISABLE_PRECOMPILE_STR) ? `` : `$DISABLE_PRECOMPILE_STR`

function is_precompile_enabled()
    opts = Base.JLOptions()
    field = PRECOMPILE_FIELD

    # When the pre-compile field is empty it means pre-compilation is unsupported. If the
    # pre-compile field is missing that means pre-compilation to be assumed to be enabled.
    return field != Symbol() && (!isdefined(opts, field) || Bool(getfield(opts, field)))
end

function enable()
    ENABLED::Bool && return  # Abend early if enabled has already been set
    global ENABLED = true
    global PATCH_ENV = PatchEnv()

    # TODO: Support programatically disabling the use of the pre-compilation flag.
    if is_precompile_enabled()
        warn(
            "Mocking.jl will probably not work when $PRECOMPILE_FLAG is enabled. " *
            "Please start Julia with `$DISABLE_PRECOMPILE_STR`",
        )
    end
end

immutable Patch
    signature::Expr
    body::Function
    modules::Set
    # translation::Dict

    function Patch(signature::Expr, body::Function, translation::Dict)
        trans = adjust_bindings(translation)
        sig = name_parameters(absolute_signature(signature, trans))

        # On VERSION >= v"0.5"
        # modules = Set(b.args[1] for b in values(trans) if isa(b, Expr))
        modules = Set()
        for b in values(trans)
            if isa(b, Expr)
                push!(modules, b.args[1])
            end
        end

        new(sig, body, modules)
    end
end

# TODO: Find non-eval way to determine module locations of Types
# evaling in the @patch scope seems to be problematic for pre-compliation
# first(methods(x)).sig.types[2:end]

# We can use the @patch macro to create a list of bindings used then pass that
# in as an array into Patch. At runtime the types and function names will be fully
# qualified

# We can support optional parameters and keywords by using generic functions on
# 0.4

function convert(::Type{Expr}, p::Patch)
    exprs = Array{Expr}(length(p.modules) + 1)

    # Generate imports for all required modules
    for (i, m) in enumerate(p.modules)
        exprs[i] = Expr(:import, splitbinding(m)...)
    end

    # Generate the new method which will call the user's patch function. We need to perform
    # this call instead of injecting the body expression to support closures.
    sig, body = p.signature, p.body
    params = call_parameters(sig)
    exprs[end] = :($sig = $body($(params...)))

    return Expr(:block, exprs...)
end

macro patch(expr::Expr)
    if expr.head == :function
        name = expr.args[1].args[1]
        params = expr.args[1].args[2:end]
        body = expr.args[2]

    # Short-form function syntax
    elseif expr.head == :(=) && expr.args[1].head == :call
        name = expr.args[1].args[1]
        params = expr.args[1].args[2:end]
        body = expr.args[2]

    # Anonymous function syntax
    # elseif expr.head == :(->)
        # TODO: Determine how this could be supported
    else
        throw(ArgumentError("expression is not a function definition"))
    end

    signature = Expr(:call, name, params...)

    # Determine the bindings used in the signature
    bindings = Bindings(signature)

    # Need to evaluate the body of the function in the context of the `@patch` macro in
    # order to support closures.
    # func = Expr(:(->), Expr(:tuple, params...), body)
    func = Expr(:(=), Expr(:call, gensym(), params...), body)

    # Generate a translation between the external bindings and the runtime types and
    # functions. The translation will be used to revise all bindings to be absolute.
    translations = [Expr(:call, :(=>), QuoteNode(b), b) for b in bindings.external]

    return esc(:(Mocking.Patch( $(QuoteNode(signature)), $func, Dict($(translations...)) )))
end

immutable PatchEnv
    mod::Module
    debug::Bool

    function PatchEnv(debug::Bool=false)
        # Be careful not to call this code during pre-compilation otherwise we'll see the
        # warning: "incremental compilation may be broken for this module"
        m = Core.eval(Mocking, :(module $(gensym()) end))
        new(m, debug)
    end
end

function PatchEnv(patches::Array{Patch}, debug::Bool=false)
    pe = PatchEnv(debug)
    apply!(pe, patches)
    return pe
end

function PatchEnv(patch::Patch, debug::Bool=false)
    pe = PatchEnv(debug)
    apply!(pe, patch)
    return pe
end

function apply!(pe::PatchEnv, p::Patch)
    Core.eval(pe.mod, convert(Expr, p))
end

function apply!(pe::PatchEnv, patches::Array{Patch})
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

function apply(body::Function, patches::Array{Patch}; debug::Bool=false)
    apply(body, PatchEnv(patches, debug))
end
function apply(body::Function, patch::Patch; debug::Bool=false)
    apply(body, PatchEnv(patch, debug))
end

function ismocked(pe::PatchEnv, func_name::Symbol, args::Tuple)
    if isdefined(pe.mod, func_name)
        func = Core.eval(pe.mod, func_name)
        types = map(arg -> isa(arg, Type) ? Type{arg} : typeof(arg), args)
        exists = method_exists(func, types)

        if pe.debug
            info("calling $func_name$(types)")
            if exists
                m = first(methods(func, types))
                info("executing mocked function: $m")
            else
                m = first(methods(Core.eval(func_name), types))
                info("executing original function: $m")
            end
        end

        return exists
    end
    return false
end

set_active_env(pe::PatchEnv) = (global PATCH_ENV = pe)
get_active_env() = PATCH_ENV::PatchEnv

macro mock(expr)
    isa(expr, Expr) || error("argument is not an expression")
    expr.head == :call || error("expression is not a function call")
    ENABLED::Bool || return esc(expr)  # @mock is a no-op when Mocking is not ENABLED

    func = expr.args[1]
    func_name = QuoteNode(func)
    args = expr.args[2:end]

    env_var = gensym("env")
    args_var = gensym("args")

    # Note: The fix to Julia issue #265 (PR #17057) introduced changes where no compiled
    # calls could be made to functions compiled afterwards. Since the `Mocking.apply`
    # do-block syntax compiles the body of the do-block function before evaluating the
    # "outer" function this means our patch functions will be compiled after the "inner"
    # function.
    result = quote
        local $env_var = Mocking.get_active_env()
        local $args_var = tuple($(args...))
        if Mocking.ismocked($env_var, $func_name, $args_var)
            Mocking.invokelatest($env_var.mod.$func, $args_var...)
        else
            $func($args_var...)
        end
    end

    return esc(result)
end

end # module
