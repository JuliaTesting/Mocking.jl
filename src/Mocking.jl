module Mocking

export @patch, @mock
export Patch, PatchEnv, apply, ismocked, set_active_env, get_active_env

# TODO:
# - [ ] Test Patch with different function syntaxes: long, short, anonymous
# - [ ] Change Patch and PatchEnv to immutable?

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
apply(patch_env::PatchEnv, p::Patch) = Core.eval(patch_env.mod, p.func)

function ismocked(patch_env::PatchEnv, func_name::Symbol, args::Tuple)
    if isdefined(patch_env.mod, func_name)
        func = Core.eval(patch_env.mod, func_name)
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

global ACTIVE_ENV = PatchEnv()
set_active_env(patch_env::PatchEnv) = (global ACTIVE_ENV = patch_env)
get_active_env() = ACTIVE_ENV

# TODO: Perform hygiene here
macro mock(expr)
    isa(expr, Expr) || error("argument is not an expression")
    expr.head == :call || error("expression is not a function call")

    func = expr.args[1]
    func_name = string(func)
    args = expr.args[2:end]
    result = quote
        local env = Mocking.get_active_env()
        # Want ...(::Module, ::Symbol, ::Array{Any})
        if Mocking.ismocked(env, Symbol($func_name), tuple($(args...)))
            env.mod.$func($(args...))
        else
            $expr
        end
    end
    return esc(result)
end

end # module
