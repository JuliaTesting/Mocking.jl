import Base: Expr, methods, ==, convert

type Signature
    types::Array{Type}
end

function Signature(f::Function)
    names, types = parameters(f)
    return Signature(types)
end

function Signature(m::Method)
    names, types = parameters(m)
    return Signature(types)
end

Signature(t::ANY) = Signature(to_array_type(t))

function methods(f::Function, sig::Signature)
    matching = methods(f, convert(Tuple, sig))
    if length(matching) > 1
        for m in matching
            Signature(m) == sig && return [m]
        end
    end
    return matching
end

==(a::Signature, b::Signature) = a.types == b.types

convert(::Type{Tuple}, s::Signature) = Tuple{s.types...}

function parameters(m::Method)
    expr = Base.uncompressed_ast(m.func.code).args[1]
    names = Array{Symbol}(length(expr))
    types = Array{Type}(length(expr))
    for (i, field) in enumerate(expr)
        names[i] = isa(field, Symbol) ? field : field.args[1]
        types[i] = m.sig.parameters[i]
    end
    return names, types
end

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

