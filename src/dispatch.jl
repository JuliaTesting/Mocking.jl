# Use Julia's `jl_type_morespecific` function to emulate Julia's multiple dispatch across
# generic functions.
#
# Origin:
# https://github.com/JuliaLang/julia/blob/master/doc/src/devdocs/types.md#subtyping-and-method-sorting
type_morespecific(a, b) = ccall(:jl_type_morespecific, Bool, (Any, Any), a, b)

"""
    anonymous_signature(m::Method) -> Type{<:Tuple}

Construct a Tuple of the methods signature with the function type removed

# Example
```@meta
DocTestSetup = quote
    using Mocking: anonymous_signature
end
```

```jldoctest
julia> m = first(methods(first, (String,)));

julia> m.sig
Tuple{typeof(first), AbstractString}

julia> anonymous_signature(m)
Tuple{AbstractString}
```

```@meta
DocTestSetup = nothing
```
"""
anonymous_signature(m::Method) = anonymous_signature(m.sig)
anonymous_signature(sig::DataType) = Tuple{sig.parameters[2:end]...}
anonymous_signature(sig::UnionAll) = UnionAll(sig.var, anonymous_signature(sig.body))

"""
    anon_morespecific(a::Method, b::Method) -> Bool

Determine which method is more specific for multiple dispatch without considering the
function type. By not considering the function type we can determine which method is more
specific as if they are a part of the same generic function.
"""
function anon_morespecific(a::Method, b::Method)
    # Drop the function type from the parameter
    a_sig = anonymous_signature(a)
    b_sig = anonymous_signature(b)

    return type_morespecific(a_sig, b_sig)
end

"""
    dispatch(funcs::AbstractVector, args...) -> Tuple{Method, Any}

Choose which method to execute based upon the provided arguments (values not types).
Emulates Julia's multiple dispatch system but allows for dispatching between methods of
multiple generic functions instead of just methods of a single generic function. Returns a
tuple of the selected method and the generic function of the method.

When the function to dispatch to is ambiguous last ambiguous function in the vector is used.
"""
function dispatch(funcs::AbstractVector, args...)
    arg_types = map(Core.Typeof, args)

    best_method = nothing
    best_function = nothing
    for f in reverse(funcs)
        # Since arguments will be using concrete types `methods` should only return up to
        # one method.
        for m in methods(f, arg_types)
            if best_method === nothing || anon_morespecific(m, best_method)
                best_method = m
                best_function = f
            end
        end
    end

    return best_method, best_function
end
