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

"""
    splitdef(ex::Expr; throw::Bool=true) -> Union{Dict{Symbol,Any}, Nothing}

Split a function definition expression into its various components including:

- `:type`: Type of the function (long-form `:function`, short-form `:(=)`, anonymous `:(->)`)
- `:name`: Name of the function (not present for anonymous functions)
- `:params`: Parametric types defined on constructors
- `:args`: Positional arguments of the function
- `:kwargs`: Keyword arguments of the function
- `:rtype`: Return type of the function
- `:whereparams`: Where parameters
- `:body`: Function body (not present for empty functions)

All components listed may not be present in the returned dictionary with the exception of
`:type` which will always be present.

If the provided expression is not a function then an exception will be raised when
`throw=true`. Use `throw=false` avoid raising an exception and return `nothing` instead.

See also: [`combinedef`](@ref)
"""
function splitdef(ex::Expr; throw::Bool=true)
    def = Dict{Symbol,Any}()

    function invalid_def(section)
        if throw
            # Using a closure ensures that `ex` contains the original full expression
            msg = "Function definition contains $section\n$(sprint(Meta.dump, ex))"
            Base.throw(ArgumentError(msg))
        else
            nothing
        end
    end

    # long-form `:function`, short-form `:(=)`, anonymous `:(->)`
    if !(ex.head === :function || ex.head === :(=) || ex.head === :(->))
        return invalid_def("invalid function type `$(repr(ex.head))`")
    end

    def[:type] = ex.head
    anon = ex.head == :(->)

    if ex.head === :function && length(ex.args) == 1  # empty function definition
        def[:name] = ex.args[1]
        return def
    elseif length(ex.args) == 2  # Expect signature and body
        def[:body] = ex.args[2]
        ex = ex.args[1]  # Focus on the function signature
    else
        quan = length(ex.args) > 2 ? "too many" : "too few"
        return invalid_def("$quan of expression arguments for `$(repr(def[:type]))`")
    end

    # Where parameters
    if ex isa Expr && ex.head === :where
        def[:whereparams] = Any[]

        while ex isa Expr && ex.head === :where
            append!(def[:whereparams], ex.args[2:end])
            ex = ex.args[1]
        end
    end

    # Return type
    if !anon && ex isa Expr && ex.head === :(::)
        def[:rtype] = ex.args[2]
        ex = ex.args[1]
    end

    # Arguments and keywords
    if ex isa Expr && (anon && ex.head === :tuple || !anon && ex.head === :call)
        i = anon ? 1 : 2

        if length(ex.args) >= i
            if ex.args[i] isa Expr && ex.args[i].head === :parameters
                def[:kwargs] = ex.args[i].args

                if length(ex.args) > i
                    def[:args] = ex.args[(i + 1):end]
                end
            else
                def[:args] = ex.args[i:end]
            end
        end
    elseif ex isa Expr && anon && ex.head === :block
        # Note: Short-form anonymous functions (:->) will use a block expression when the
        # arguments are divided by semi-colons but do not use commas:
        #
        # (;) -> ...
        # (x;) -> ...
        # (x;y) -> ...
        # (;x) -> ...  # Note: this is an exception to this rule

        for arg in ex.args
            arg isa LineNumberNode && continue

            if !haskey(def, :args)
                def[:args] = [arg]
            elseif !haskey(def, :kwargs)
                def[:kwargs] = [arg]
            else
                return invalid_def("an invalid block expression as arguments")
            end
        end

        !haskey(def, :kwargs) && (def[:kwargs] = [])

    elseif anon
        def[:args] = [ex]
    else
        return invalid_def("invalid or missing arguments")
    end

    # Function name and type parameters
    if !anon
        ex = ex.args[1]

        if ex isa Expr && ex.head === :curly
            def[:params] = ex.args[2:end]
            ex = ex.args[1]
        end

        def[:name] = ex
    end

    return def
end

"""
    combinedef(def::Dict{Symbol,Any}) -> Expr

Create a function definition expression from various components. Typically used to construct
a function using the result of [`splitdef`](@ref).

For more details see the documentation on [`splitdef`](@ref).
"""
function combinedef(def::Dict{Symbol,Any})
    # Determine the name of the function including parameterization
    name = if haskey(def, :params)
        Expr(:curly, def[:name], def[:params]...)
    elseif haskey(def, :name)
        def[:name]
    else
        nothing
    end

    # Empty generic function definitions must not contain additional keys
    if !haskey(def, :body) && any(k -> haskey(def, k), [:args, :kwargs, :rtype, :whereparams])
        extra = [:args, :kwargs, :rtype, :whereparams]
        throw(ArgumentError(string(
            "Function definitions without a body must not contain keys: ",
            join(string.('`', repr.(setdiff(extra, keys(def))), '`'), ", ", ", or "),
        )))
    end

    # Combine args and kwargs
    args = Any[]
    haskey(def, :kwargs) && push!(args, Expr(:parameters, def[:kwargs]...))
    haskey(def, :args) && append!(args, def[:args])

    # Create a partial function signature including the name and arguments
    sig = if name !== nothing
        Expr(:call, name, args...)
    elseif length(args) != 1 || args[1] isa Expr && args[1].head in (:kw, :parameters)
        Expr(:tuple, args...)
    else
        args[1]
    end

    # Add the return type
    if haskey(def, :rtype)
        sig = Expr(:(::), sig, def[:rtype])
    end

    # Add any where parameters. Note: Always uses the curly where syntax
    if haskey(def, :whereparams)
        sig = Expr(:where, sig, def[:whereparams]...)
    end

    func = if haskey(def, :body)
        Expr(def[:type], sig, def[:body])
    else
        Expr(def[:type], name)
    end

    return func
end
