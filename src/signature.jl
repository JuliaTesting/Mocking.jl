doc"""
Determines the type signature of an anonymous function
"""
function signature(f::Function)
    isgeneric(f) && throw(ArgumentError("only works for anonymous functions"))
    expr = Base.uncompressed_ast(f.code).args[1]
    sig = Array{Type}(length(expr))
    for (i, field) in enumerate(expr)
        sub = field.args[2]
        if isa(sub, Expr) && sub.head == :...
            sig[i] = Vararg{eval(sub.args[1])}
        else
            sig[i] = eval(sub)
        end
    end
    return eval(:(Tuple{$(sig...)}))
end

function array(signature::Type)
    signature <: Tuple || throw(ArgumentError("signature expected to be a Tuple type"))
    expr = parse(string(signature))  # Note: :($signature) should work but doesn't
    isa(expr, Symbol) && return Type[]  # When signature = Tuple
    sig = Array{Type}(length(expr.args) - 1)
    for i in 1:length(expr.args) - 1
        sig[i] = eval(expr.args[i + 1])
    end
    return sig
end
