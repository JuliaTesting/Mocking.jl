__precompile__(true)

module Mocking

import Compat: invokelatest

include("expr.jl")

export @patch, @mock, Patch, apply

# When ENABLED is false the @mock macro is a noop.
global ENABLED = false
global PATCH_ENV = nothing

function enable()
    ENABLED::Bool && return  # Abend early if enabled has already been set
    global ENABLED = true
    global PATCH_ENV = PatchEnv()

    # TODO: Support programatically disabling the use of the compilecache.
    opts = Base.JLOptions()
    if isdefined(opts, :use_compilecache) && Bool(opts.use_compilecache)
        warn("Mocking.jl will probably not work when compilecache is enabled. Please start Julia with `--compilecache=no`")
    end
end

immutable Patch
    signature::Expr
    body::Function
    modules::Set
    # translation::Dict

    function Patch(signature::Expr, body::Function, translation::Dict)
        trans = adjust_bindings(translation)
        sig = absolute_sig(signature, trans)
        modules = Set([v.args[1] for v in values(trans)])  # Square brackets only needed on Julia 0.4
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
    sig, body = p.signature, p.body
    params = call_parameters(sig)
    return :($sig = $body($(params...)))
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

    # Determine the modules required for the parameter types
    bindings = unique(extract_bindings(params))

    signature = QuoteNode(Expr(:call, name, params...))

    # Need to evaluate the body of the function in the context of the `@patch` macro in
    # order to support closures.
    # func = Expr(:(->), Expr(:tuple, params...), body)
    func = Expr(:(=), Expr(:call, gensym(), params...), body)

    # Generate a translation between the binding Symbols and the runtime types and
    # functions. The translation will be used to revise all bindings to be absolute.
    translations = [Expr(:call, :(=>), QuoteNode(b), b) for b in bindings]

    return esc(:(Mocking.Patch( $signature, $func, Dict($(translations...)) )))
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
    for m in p.modules
        Core.eval(pe.mod, Expr(:import, splitbinding(m)...))
    end
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
        types = map(typeof, tuple(args...))
        exists = method_exists(func, types)

        if pe.debug
            info("calling $func_name($(types...))")
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
