# Looks at a function signature and separates the bindings (variable names, function calls,
# parametric variables) into those created by the function signature and those that are
# external. The external bindings will be turned into absolute bindings.

struct Bindings
    internal::Set
    external::Set
end

Bindings() = Bindings(Set(), Set())

function Bindings(internal::AbstractArray, external::AbstractArray)
    Bindings(Set(internal), Set(external))
end

"""
    Bindings(expr)

Takes a function signature expression and extracts all of the bindings into either internal
(defined by the signature) or external (defined outside of the signature).

```julia
julia> Bindings(:(f{T<:Integer}(a::T, b::Base.Real=a, c=z)))
Mocking.Bindings(Set(Any[:c,:T,:a,:b,:f]),Set(Any[:z,:(Base.Real),:Integer]))
```
"""
Bindings(expr::Expr) = ingest_signature!(Bindings(), expr)

function ingest_parametric!(b::Bindings, expr::Expr)
    if expr.head in (:(<:), :(>:))
        defined, reference = expr.args
        push!(b.internal, defined)
        !(reference in b.internal) && push!(b.external, reference)

    # Chained operator comparison
    elseif expr.head == :comparison && length(expr.args) == 5 &&
        expr.args[2] == expr.args[4] && expr.args[2] in (:(<:), :(>:))

        reference_before = expr.args[1]
        defined = expr.args[3]
        reference_after = expr.args[5]

        # Note chaining more than two operators here is unsupported by Julia
        !(reference_before in b.internal) && push!(b.external, reference_before)
        push!(b.internal, defined)
        !(reference_after in b.internal) && push!(b.external, reference_after)
    else
        error("expression is not valid parametric expression: $expr")
    end
    return b
end

function ingest_parametric!(b::Bindings, sym::Symbol)
    push!(b.internal, sym)
    return b
end

function ingest_assertion!(b::Bindings, expr::Expr)
    # Tuple{Int}
    if expr.head == :curly
        for ex in expr.args
            ingest_assertion!(b, ex)
        end

    # ...{<:Integer}
    elseif expr.head in (:(<:), :(>:))
        reference = expr.args[1]
        !(reference in b.internal) && push!(b.external, reference)

    # Core.Int and Base.Random.rand
    elseif expr.head == :.
        reference = expr
        !(reference in b.internal) && push!(b.external, reference)

    # typeof(func)
    elseif expr.head == :call
        func, args = expr.args[1], expr.args[2:end]
        !(func in b.internal) && push!(b.external, func)
        for arg in args
            ingest_assertion!(b, arg)
        end

    else
        error("expression is not type assertion: $expr")
    end
    return b
end

function ingest_assertion!(b::Bindings, sym::Symbol)
    !(sym in b.internal) && push!(b.external, sym)
    return b
end

ingest_assertion!(b::Bindings, ::Any) = b

function ingest_default!(b::Bindings, expr::Expr)
    if expr.head == :call
        func, args = expr.args[1], expr.args[2:end]
        !(func in b.internal) && push!(b.external, func)
        for arg in args
            ingest_default!(b, arg)
        end

    elseif expr.head == :... || expr.head == :vect || expr.head == :tuple
        for arg in expr.args
            ingest_default!(b, arg)
        end

    # Core.Int and Base.Random.rand
    elseif expr.head == :.
        reference = expr
        !(reference in b.internal) && push!(b.external, reference)

    else
        error("expression is not valid as a parameter default: $expr")
    end
    return b
end

function ingest_default!(b::Bindings, sym::Symbol)
    !(sym in b.internal) && push!(b.external, sym)
    return b
end

ingest_default!(b::Bindings, ::Any) = b

function ingest_parameter!(b::Bindings, expr::Expr)
    # Positional parameter
    if expr.head == :(::) && length(expr.args) == 2
        defined, reference = expr.args
        push!(b.internal, defined)
        ingest_assertion!(b, reference)

    # Anonymous positional parameter
    elseif expr.head == :(::) && length(expr.args) == 1
        reference, = expr.args
        ingest_assertion!(b, reference)

    # Optional parameter
    elseif expr.head == :kw
        parameter, value = expr.args
        ingest_parameter!(b, parameter)
        ingest_default!(b, value)

    # Keyword parameters
    elseif expr.head == :parameters
        for parameter in expr.args
            ingest_parameter!(b, parameter)
        end

    # Varargs parameter
    elseif expr.head == :...
        for parameter in expr.args
            ingest_parameter!(b, parameter)
        end

    else
        error("expression is not valid as a parameter: $expr")
    end
    return b
end

function ingest_parameter!(b::Bindings, sym::Symbol)
    push!(b.internal, sym)
    return b
end

function ingest_signature!(b::Bindings, expr::Expr)
    if expr.head == :call
        func = expr.args[1]

        # f(...)
        if isa(func, Symbol)
            push!(b.internal, func)

        # f{T}(...)
        elseif isa(func, Expr) && func.head == :curly
            push!(b.internal, func.args[1])
            for parametric in func.args[2:end]
                ingest_parametric!(b, parametric)
            end
        else
            error("expression is not a valid function call: $func")
        end

        # Function parameters and keywords
        for parameter in expr.args[2:end]
            ingest_parameter!(b, parameter)
        end

    # f(...) where T
    elseif expr.head == :where
        for parametric in expr.args[2:end]
            ingest_parametric!(b, parametric)
        end
        ingest_signature!(b, expr.args[1])

    else
        error("expression is not valid as signature: $expr")
    end
    return b
end
