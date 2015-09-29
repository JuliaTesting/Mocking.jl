import Base: methods, ==

type Signature
    types::Array{Type}
end

function Signature(f::Function)
    names, types = parameters(f)
    return Signature(types)
end

Signature(m::Method) = Signature(m.func)

function methods(f::Function, sig::Signature)
    matching = methods(f, Tuple(sig))
    if length(matching) > 1
        for m in matching
            Signature(m) == sig && return [m]
        end
    end
    return matching
end

Tuple(s::Signature) = Tuple{s.types...}
==(a::Signature, b::Signature) = a.types == b.types


function parameters(f::Function)
    isgeneric(f) && throw(ArgumentError("only works for anonymous functions"))
    expr = Base.uncompressed_ast(f.code).args[1]
    names = Array{Symbol}(length(expr))
    types = Array{Type}(length(expr))
    for (i, field) in enumerate(expr)
        name, typ = isa(field, Symbol) ? (field, Any) : field.args
        names[i] = name
        if isa(typ, Expr) && typ.head == :...
            types[i] = Vararg{eval(typ.args[1])}
        else
            types[i] = eval(typ)
        end
    end
    return names, types
end