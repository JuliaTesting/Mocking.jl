using Base: unwrap_unionall

if VERSION < v"0.7.0-DEV.3539"
    nameof(f::Function) = Base.function_name(f)
end

if VERSION < v"0.7.0-DEV.3460"
    parentmodule(f, t) = Base.function_module(f, t)
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
function binding_expr(u::Union)
    a = binding_expr(u.a)
    b = binding_expr(u.b)
    if b.head == :curly && b.args[1] == :Union
        Expr(:curly, :Union, a, b.args[2:end]...)
    else
        Expr(:curly, :Union, a, b)
    end
end
function binding_expr(f::Function)
    if isa(f, Core.Builtin)
        return nameof(f)
    end
    m = parentmodule(f, Tuple)
    joinbinding(fullname(m)..., nameof(f))
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
        args = Array{Any}(undef, num_args)
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
        args = Array{Any}(undef, num_args)
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
                    if ex.head == :...
                        name = variable_name(ex.args[1])
                        push!(keywords, Expr(:..., name))
                    else
                        name = variable_name(ex)
                        push!(keywords, Expr(:kw, name, name))
                    end
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

# New do-block syntax introduced in: https://github.com/JuliaLang/julia/pull/23718
function rewrite_do(expr::Expr)
    expr.head == :do || error("expression is not a do-block")
    call, body = expr.args
    Expr(:call, call.args[1], body, call.args[2:end]...)
end

iskwarg(x::Any) = isa(x, Expr) && (x.head === :parameters || x.head === :kw)

"""
    extract_kwargs(expr::Expr) -> Vector{Expr}

Extract the :parameters and :kw value into an array of :kw expressions
we don't evaluate any expressions for values yet though.
"""
function extract_kwargs(expr::Expr)
    kwargs = Expr[]
    for x in expr.args[2:end]
        if Mocking.iskwarg(x)
            if x.head === :parameters
                for kw in x.args
                    push!(kwargs, kw)
                end
            else
                push!(kwargs, x)
            end
        end
    end
    return kwargs
end
