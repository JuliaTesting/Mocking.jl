module Mocking

export @patch, @mock
export Patch, PatchEnv, apply, ismocked, set_active_env, get_active_env

# TODO:
# - [ ] Test Patch with different function syntaxes: long, short, anonymous
# - [ ] Change Patch and PatchEnv to immutable?
# - [ ] Use baremodule to avoid debugging stating things like: using mocked version of
#       == when == wasn't explicity mocked.

type Patch
    func::Expr

    function Patch(expr::Expr)
        # Long-form function syntax
        if expr.head == :function
            new(expr)
        # Short-form function syntax
        elseif expr.head == :(=) && expr.args[1].head == :call
            new(expr)
        # Anonymous function syntax
        # elseif expr.head == :(->)
            # TODO: Determine how this could be supported
        else
            throw(ArgumentError("expression is not a function definition"))
        end
    end
end

name(p::Patch) = p.func.args[1].args[1]
parameters(p::Patch) = p.func.args[1].args[2:end]
body(p::Patch) = p.func.args[2]

macro patch(expr::Expr)
    Patch(expr)
end

type PatchEnv
    mod::Module

    function PatchEnv()
        m = eval(:(module $(gensym()) end))  # generate a module
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
    set_active_env(pe)
    return body()
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
    func_name = string(func)
    _args = expr.args[2:end]
    result = quote
        local env = Mocking.get_active_env()
        local args = tuple($(_args...))
        # Want ...(::Module, ::Symbol, ::Array{Any})
        if Mocking.ismocked(env, Symbol($func_name), args)
            env.mod.$func(args...)
        else
            $func(args...)
        end
    end
    return esc(result)
end

end # module
