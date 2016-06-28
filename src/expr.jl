function qualify_types!(params::Array)
    modules = Union{Expr,Symbol}[]
    for p in params
        if isa(p, Expr)
            # Positional parameter
            if p.head == :(::)
                t = qualify_type(p.args[2])
                p.args[2] = t
                push!(modules, t.args[1])

            # Optional parameter
            elseif p.head == :kw && isa(p.args[1], Expr)
                t = qualify_type(p.args[1].args[2])
                p.args[1].args[2] = t
                push!(modules, t.args[1])

            # Keyword parameters
            elseif p.head == :parameters
                append!(modules, qualify_types!(p.args))
            end
        end
    end
    return modules
end

function qualify_type(expr::Union{Expr,Symbol})
    typ = Core.eval(expr)
    m = fullname(typ.name.module)
    if isa(expr, Expr)
        type_expr = expr.args[2]
        if isa(type_expr, Expr) && type_expr.head == :quote
            type_sym = type_expr.args[1]
        else
            type_sym = type_expr
        end
    else
        type_sym = expr
    end
    return joinpath(m..., type_sym)
end

function joinpath(symbols::Symbol...)
    result = symbols[1]
    for s in symbols[2:end]
        result = Expr(:., result, QuoteNode(s))
    end
    return result
end
