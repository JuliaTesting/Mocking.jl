# New do-block syntax introduced in: https://github.com/JuliaLang/julia/pull/23718
function rewrite_do(expr::Expr)
    expr.head == :do || error("expression is not a do-block")
    call, body = expr.args
    Expr(:call, call.args[1], body, call.args[2:end]...)
end

iskwarg(x::Any) = isa(x, Expr) && (x.head === :parameters || x.head === :kw)

"""
    extract_kwargs(expr::Expr) -> Vector{Union{Expr,Symbol}}

Extract the :parameters and :kw value into an array of :kw expressions
we don't evaluate any expressions for values yet though.
"""
function extract_kwargs(expr::Expr)
    kwargs = Union{Expr,Symbol}[]
    for x in expr.args[2:end]
        if iskwarg(x)
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
