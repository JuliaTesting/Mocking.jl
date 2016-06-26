module Mocking

export Patch, @patch, Mock, add, @mock, create_mocking_env, get_mocking_env, use_mocked

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

generate_env() = eval(:(module $(gensym()) end))

global MOCKING_ENV = generate_env()

function create_mocking_env()
    global MOCKING_ENV
    MOCKING_ENV = generate_env()
end

function get_mocking_env()
    global MOCKING_ENV
    return MOCKING_ENV
end

function add(p::Patch)
    global MOCKING_ENV
    Core.eval(MOCKING_ENV, p.func)
end

function use_mocked(env::Module, func_name::Symbol, args::Array)
    if isdefined(env, func_name)
        func = Core.eval(env, func_name)
        @show func
        types = map(typeof, tuple(args...))
        return length(methods(func, types)) > 0
    end
    return false
end

macro mock(expr)
    esc(mock(expr))
end

function mock(expr::Expr)
    if expr.head == :call
        func = expr.args[1]
        func_name = string(func)
        args = expr.args[2:end]
        quote
            local env = get_mocking_env()
            # Want ...(::Module, ::Symbol, ::Array{Any})
            if use_mocked(env, Symbol($func_name), $args)
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
