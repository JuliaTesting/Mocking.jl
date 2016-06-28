function qualify!(exprs::Array)
    modules = Union{Expr,Symbol}[]
    for ex in exprs
        if isa(ex, Expr)
            # Positional parameter
            if ex.head == :(::)
                q = qualify(ex.args[2])
                ex.args[2] = q
                push!(modules, q.args[1])

            # Optional parameter
            elseif ex.head == :kw && isa(ex.args[1], Expr)
                q = qualify(ex.args[1].args[2])
                ex.args[1].args[2] = q
                push!(modules, q.args[1])
                append!(modules, qualify!(ex.args[2:2]))

            # Keyword parameters
            elseif ex.head == :parameters
                append!(modules, qualify!(ex.args))

            # Default values for optional or keyword parameters
            elseif ex.head == :call
                q = qualify(ex.args[1])
                ex.args[1] = q
                push!(modules, q.args[1])
                append!(modules, qualify!(ex.args[2:end]))
            end
        end
    end
    return modules
end

function qualify(expr::Union{Expr,Symbol})
    binding = Core.eval(expr)
    m = fullname(binding.name.module)
    if isa(expr, Expr)
        name_expr = expr.args[2]
        if isa(name_expr, Expr) && name_expr.head == :quote
            name_sym = name_expr.args[1]
        else
            name_sym = name_expr
        end
    else
        name_sym = expr
    end
    return joinpath(m..., name_sym)
end

function joinpath(symbols::Symbol...)
    result = symbols[1]
    for s in symbols[2:end]
        result = Expr(:., result, QuoteNode(s))
    end
    return result
end
