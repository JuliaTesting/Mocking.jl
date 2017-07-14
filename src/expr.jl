# Note: Needed for compatibility with the Julia 0.6 type system change:
# https://github.com/JuliaLang/julia/pull/18457
if isdefined(Base, :unwrap_unionall)
    import Base: unwrap_unionall
else
    unwrap_unionall(t::Type) = t
end


"""
    binding_expr(x) -> Expr

Converts a Module, Type, or Function into an expression which includes the entire module
hierarchy.

```julia
julia> binding_expr(Int8)
:(Core.Int8)

julia> binding_expr(Dates.Hour)
:(Base.Dates.Hour)
```
"""
function binding_expr end

function binding_expr(m::Module)
    joinbinding(fullname(m)...)
end
function binding_expr(t::Type)
    type_name = unwrap_unionall(t).name
    joinbinding(fullname(type_name.module)..., type_name.name)
end
function binding_expr(f::Function)
    if VERSION >= v"0.5-" && isa(f, Core.Builtin)
        return Base.function_name(f)
    elseif VERSION < v"0.5-" && !isgeneric(f)
        if isdefined(f, :env) && isa(f.env, Symbol)
            return f.env
        else
            return Base.function_name(f)
        end
    end
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


function absolute_signature(expr::Expr, translations::Dict)
    if expr.head == :.
        return get(translations, expr, expr)
    else
        num_args = length(expr.args)
        args = Array{Any}(num_args)
        for i in 1:num_args
            args[i] = absolute_signature(expr.args[i], translations)
        end
        return Expr(expr.head, args...)
    end
end

function absolute_signature(sym::Symbol, translations::Dict)
    return get(translations, sym, sym)
end

absolute_signature(x::Any, translations::Dict) = x

function name_parameters(expr::Expr)
    if expr.head == :(::) && length(expr.args) == 1
        return Expr(expr.head, gensym("anon"), expr.args[1])
        # return Expr(expr.head, :anon, expr.args[1])
    else
        num_args = length(expr.args)
        args = Array{Any}(num_args)
        for i in 1:num_args
            args[i] = name_parameters(expr.args[i])
        end
        return Expr(expr.head, args...)
    end
end

name_parameters(x::Any) = x



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
