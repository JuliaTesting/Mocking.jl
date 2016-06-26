module Mocking

export @patch, @mock
export Patch, PatchEnv, apply, ismocked, set_active_env, get_active_env


type Patch
    func::Expr

    function Patch(expr::Expr)
        # Shortform function definition
        if expr.head == :(=) && expr.args[1].head == :call
            new(expr)
        else
            error("Not a function definition")
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

function ismocked(patch_env::PatchEnv, func_name::Symbol, args::Array)
    if isdefined(patch_env.mod, func_name)
        func = Core.eval(patch_env.mod, name)
        types = map(typeof, tuple(args...))
        return method_exists(func, types)
    end
    return false
end

global ACTIVE_ENV = PatchEnv()
set_active_env(patch_env::PatchEnv) = (global ACTIVE_ENV = patch_env)
get_active_env() = ACTIVE_ENV

# TODO: Perform hygiene here
macro mock(expr)
    esc(mock(expr))
end

function mock(expr::Expr)
    if expr.head == :call
        func = expr.args[1]
        func_name = string(func)
        args = expr.args[2:end]
        quote
            local env = Mocking.get_active_env()
            # Want ...(::Module, ::Symbol, ::Array{Any})
            if Mocking.ismocked(env, Symbol($func_name), $args)
                env.$func($(args...))
            else
                $expr
            end
        end
    else
        error("not a call")
    end
end

end # module
