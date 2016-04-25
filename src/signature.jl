import Base: Expr, methods, ==, convert

type Signature
    types::Array{Type}

    Signature(t) = new(to_array_type(t))
end

function Signature(m::TypeMapEntry)
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

function parameters(m::TypeMapEntry)
    # Remove the function name and its type
    slotnames = m.func.lambda_template.slotnames[2:end]
    specTypes = m.func.lambda_template.specTypes.parameters[2:end]

    nargs = min(length(slotnames), length(specTypes))

    names = Array{Symbol}(nargs)
    types = Array{Type}(nargs)
    for (i, (field, argtype)) in enumerate(zip(slotnames, specTypes))
        names[i] = isa(field, Symbol) ? field : field.args[1]
        types[i] = argtype
    end

    return names, types
end

function parameters(f::Function)
    m = methods(f)
    if length(m) > 1
        throw(ArgumentError("only works for functions with a single method"))
    end
    return parameters(first(m))
end

