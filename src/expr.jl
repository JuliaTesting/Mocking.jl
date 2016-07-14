function extract_bindings(exprs::AbstractArray)
    bindings = Set{Union{Expr,Symbol}}()
    for ex in exprs
        if isa(ex, Expr)
            # Positional parameter
            if ex.head == :(::)
                push!(bindings, ex.args[2])

            # Optional parameter
            elseif ex.head == :kw && isa(ex.args[1], Expr)
                push!(bindings, ex.args[1].args[2])
                union!(bindings, extract_bindings(ex.args[2:2]))

            # Keyword parameters
            elseif ex.head == :parameters
                union!(bindings, extract_bindings(ex.args))

            # Varargs parameter
            elseif ex.head == :...
                union!(bindings, extract_bindings(ex.args))

            # Default values for optional or keyword parameters
            elseif ex.head == :call
                push!(bindings, ex.args[1])
                union!(bindings, extract_bindings(ex.args[2:end]))
            end
        end
    end
    return bindings
end

function binding_expr(t::Type)
    joinbinding(fullname(t.name.module)..., t.name.name)
end
function binding_expr(f::Function)
    m = Base.function_module(f, Tuple)
    joinbinding(fullname(m)..., Base.function_name(f))
end



function adjust_bindings(translations::Dict)
    new_trans = Dict()
    for (k, v) in translations
        new_trans[k] = binding_expr(v)
    end
    return new_trans
end



function absolute_binding!(expr::Expr, translations::Dict)
    # Positional parameter
    if expr.head == :(::)
        binding = expr.args[2]
        expr.args[2] = translations[binding]

    # Optional parameter
    elseif expr.head == :kw && isa(expr.args[1], Expr)
        binding = expr.args[1].args[2]
        expr.args[1].args[2] = translations[binding]
        absolute_binding!(expr.args[2:2], translations)

    # Keyword parameters
    elseif expr.head == :parameters
        absolute_binding!(expr.args, translations)

    # Varargs parameter
    elseif expr.head == :...
        absolute_binding!(expr.args, translations)

    # Default values for optional or keyword parameters
    elseif expr.head == :call
        binding = expr.args[1]
        expr.args[1] = translations[binding]
        absolute_binding!(expr.args[2:end], translations)
    end
    expr
end

function absolute_binding!(exprs::Array, translations::Dict)
    for expr in exprs
        if isa(expr, Expr)
           absolute_binding!(expr, translations)
        end
    end
    exprs
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

            # Varargs parameter
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
