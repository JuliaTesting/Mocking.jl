module Mocking

include("expr.jl")

export @patch, @mock, Patch, apply


const GENERIC_ANONYMOUS = VERSION >= v"0.5-"

# When ALLOW_MOCK is false the @mock macro is a noop.
const ALLOW_MOCK = if isdefined(Base, :PROGRAM_FILE) && !haskey(ENV, "JULIA_TEST")
    basename(Base.PROGRAM_FILE) != "runtests.jl"
else
    state = get(ENV, "JULIA_TEST", "0")
    if state == "1" || state == "true"
        true
    elseif state == "0" || state == "false"
        false
    else
        error("expected JULIA_TEST to be \"0\" or \"1\"")
    end
end

immutable Patch
    signature::Expr
    body::Function
    modules::Array{Union{Expr,Symbol}}
end

function convert(::Type{Expr}, p::Patch)
    sig, body = p.signature, p.body
    params = sig.args[2:end]
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
    modules = unique(qualify!(params; anonymous_safe=!GENERIC_ANONYMOUS))

    signature = QuoteNode(Expr(:call, name, params...))
    func = Expr(:(->), Expr(:tuple, params...), body)
    esc(:(Mocking.Patch($signature, $func, $modules)))
end

immutable PatchEnv
    mod::Module
    debug::Bool

    function PatchEnv(debug::Bool=false)
        m = eval(:(module $(gensym()) end))  # generate a module
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

global PATCH_ENV = PatchEnv()
set_active_env(pe::PatchEnv) = (global PATCH_ENV = pe)
get_active_env() = PATCH_ENV

macro mock(expr)
    isa(expr, Expr) || error("argument is not an expression")
    expr.head == :call || error("expression is not a function call")
    ALLOW_MOCK || return esc(expr)

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
