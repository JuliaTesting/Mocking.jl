import Base: Expr, methods, ==, convert

type Signature
    types::Array{Type}

    Signature(t) = new(to_array_type(t))
end

function Signature(m::Method)
    names, types = parameters(m)
    return Signature(types)
end

function Signature(f::Function)
    names, types = parameters(f)
    return Signature(types)
end

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
    expr = Base.uncompressed_ast(m.func).args[1]
    names = Array{Symbol}(length(expr))
    types = Array{Type}(length(expr))
    for (i, field) in enumerate(expr)
        names[i] = isa(field, Symbol) ? field : field.args[1]
        types[i] = m.sig.parameters[i]
    end

    # Remove the function name and its type
    return names[2:end], types[2:end]
end

function parameters(f::Function)
    m = methods(f)
    if length(m) > 1
        throw(ArgumentError("only works for functions with a single method"))
    end
    return parameters(first(m))
end

