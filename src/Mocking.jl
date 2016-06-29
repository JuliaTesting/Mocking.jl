__precompile__(true)

module Mocking

include("expr.jl")

export @patch, @mock, Patch, apply

function __init__()
    const global GENERIC_ANONYMOUS = VERSION >= v"0.5-"

    # When ENABLED is false the @mock macro is a noop.
    global ENABLED = false
    global PATCH_ENV = PatchEnv()

    # Attempt to detect when Mocking has been imported while running within Pkg.test()
    if isdefined(Base, :PROGRAM_FILE) && basename(PROGRAM_FILE) == "runtests.jl"
        enable()
    end
end

function enable()
    ENABLED && return  # Abend early if enabled has already been set
    global ENABLED = true

    # TODO: Support programatically disabling the use of the compilecache.
    opts = Base.JLOptions()
    if isdefined(opts, :use_compilecache) && Bool(opts.use_compilecache)
        warn("Mocking.jl will not probably not work when compilecache is enabled. Please start Julia with `--compilecache=no`")
    end
end

immutable Patch
    signature::Expr
    body::Function
    modules::Set
    # translation::Dict

    function Patch(signature::Expr, body::Function, translation::Dict)
        trans = adjust_bindings(translation)
        absolute_binding!(signature.args[2:end], trans)  # TODO: Don't like that signature is modified
        modules = Set([v.args[1] for v in values(trans)])
        new(signature, body, modules)
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

    translations = []
    for b in bindings
        push!(translations, Expr(:(=>), QuoteNode(b), b))
    end

    return esc(:(Mocking.Patch( $signature, $func, Dict($(translations...)) )))
end

immutable PatchEnv
    mod::Module
    debug::Bool

    function PatchEnv(debug::Bool=false)
        # Generate a new module. TODO: pre-compilation doesn't like us creating new
        # modules. One workaround is to pre-create a finite amount of empty modules.
        m = Core.eval(Mocking, :(module $(gensym()) end))  # generate a module
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
get_active_env() = PATCH_ENV

macro mock(expr)
    isa(expr, Expr) || error("argument is not an expression")
    expr.head == :call || error("expression is not a function call")
    ENABLED || return esc(expr)

    func = expr.args[1]
    func_name = QuoteNode(func)
    args = expr.args[2:end]

    env_var = gensym("env")
    args_var = gensym("args")

    result = quote
        local $env_var = Mocking.get_active_env()
        local $args_var = tuple($(args...))
        if Mocking.ismocked($env_var, $func_name, $args_var)
            $env_var.mod.$func($args_var...)
        else
            $func($args_var...)
        end
    end

    return esc(result)
end

end # module
