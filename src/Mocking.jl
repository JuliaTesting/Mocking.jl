module Mocking

export @patch, @mock
export Patch, PatchEnv, apply, ismocked, set_active_env, get_active_env

# TODO:
# - [ ] Test Patch with different function syntaxes: long, short, anonymous

immutable Patch
    func::Expr

    function Patch(signature::Expr, body::Function)
        params = signature.args[2:end]
        new(:($signature = $body($(params...))))
    end
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

    signature = QuoteNode(Expr(:call, name, params...))
    func = Expr(:(->), Expr(:tuple, params...), body)
    esc(:(Mocking.Patch($signature, $func)))
end

immutable PatchEnv
    mod::Module

    function PatchEnv()
        m = eval(:(baremodule $(gensym()) end))  # generate a module
        new(m)
    end
end

function PatchEnv(patches::Array{Patch})
    pe = PatchEnv()
    apply!(pe, patches)
    return pe
end

function PatchEnv(patch::Patch)
    pe = PatchEnv()
    apply!(pe, patch)
    return pe
end

apply!(pe::PatchEnv, p::Patch) = Core.eval(pe.mod, p.func)

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

apply(body::Function, patches::Array{Patch}) =  apply(body, PatchEnv(patches))
apply(body::Function, patch::Patch) = apply(body, PatchEnv(patch))

function ismocked(pe::PatchEnv, func_name::Symbol, args::Tuple)
    if isdefined(pe.mod, func_name)
        func = Core.eval(pe.mod, func_name)
        types = map(typeof, tuple(args...))
        exists = method_exists(func, types)
        println("$func_name($(types...))")
        if exists
            m = first(methods(func, types))
            println("executing mocked function: $m")
        else
            ms = methods(Core.eval(func_name), types)
            println(ms)
            m = first(ms)
            println("executing original function: $m")
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
