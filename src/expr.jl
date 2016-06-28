function qualify!(exprs::Array; anonymous_safe::Bool=false)
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
                anonymous_safe && error("optional parameters are not allowed")
                q = qualify(ex.args[1].args[2])
                ex.args[1].args[2] = q
                push!(modules, q.args[1])
                append!(modules, qualify!(ex.args[2:2]))

            # Keyword parameters
            elseif ex.head == :parameters
                anonymous_safe && error("keyword parameters are not allowed")
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
    return joinbinding(m..., name_sym)
end

function joinbinding(symbols::Symbol...)
    result = symbols[1]
    for s in symbols[2:end]
        result = Expr(:., result, QuoteNode(s))
    end
    return result
end

function splitbinding(expr::Union{Expr,Symbol})
    parts = Symbol[]
    if isa(expr, Expr) && expr.head == :.
        append!(parts, splitbinding(expr.args[1]))
        tail = expr.args[2]
        push!(parts, isa(tail, QuoteNode) ? tail.value : tail)
    else
        push!(parts, expr)
    end
    return parts
end

function variable_name(expr::Expr)
    # Positional parameter, with type assertion
    if expr.head == :(::)
        name = expr.args[1]  # x::Integer

    # Optional parameter
    elseif expr.head == :kw
        if isa(expr.args[1], Symbol)
            name = expr.args[1]  # x=0
        else
            name = expr.args[1].args[1]  # x::Integer=0
        end

    else
        error("Unable to process expression")
    end
    return name
end
variable_name(sym::Symbol) = sym

function call_parameters(expr::Expr)
    keywords = Expr[]
    positional = Any[]
    expr.head == :call || error("expression is not a call")
    for expr in expr.args[2:end]
        if isa(expr, Expr)
            # Keyword parameters
            if expr.head == :parameters
                for ex in expr.args
                    name = variable_name(ex)
                    push!(keywords, Expr(:kw, name, name))
                end

             # Varags parameter
            elseif expr.head == :...
                name = variable_name(expr.args[1])
                push!(positional, Expr(:..., name))
            else
                push!(positional, variable_name(expr))
            end
        else
            push!(positional, variable_name(expr))
        end
    end
    if !isempty(keywords)
        positional = vcat(Expr(:parameters, keywords...), positional)
    end
    return positional
end
