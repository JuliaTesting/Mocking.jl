struct KwArgs{T}
    values::T
end

struct Patch
    signature::Expr
    body::Function

end

function Patch(
    signature::Expr,
    body::Function,
    source_module::Module,
    translation::Dict)

    trans = adjust_bindings(source_module, translation)
    sig = name_parameters(absolute_signature(signature, trans))


    Patch(sig, body)
end


macro patch(expr::Expr)
    #TODO Make sure all varients of `where` work
    @capture(expr,
        function name_(params__) body_ end |
        (name_(params__) = body_)
    ) || throw(ArgumentError("expression is not a function definition"))

    signature = Expr(:call, name, params...)



    # Generate a translation between the external bindings and the runtime types and
    # functions. The translation will be used to revise all bindings to be absolute.
    bindings = Bindings(signature)
    translations = [Expr(:call, :(=>), QuoteNode(b), b) for b in bindings.external]


    # Need to evaluate the body of the function in the context of the `@patch` macro in
    # order to support closures.
    # func = Expr(:(->), Expr(:tuple, params...), body)
    func = Expr(:(=), Expr(:call, gensym(Symbol(name, :_patch)), params...), body)


    return esc(:(Mocking.Patch(
        $(QuoteNode(signature)),
        $func,
        $(QuoteNode(__module__)),
        Dict($(translations...))
    )))
end



"""
    code_for_apply_patch(ctx_name, patch)

Returns an `Expr` that when evaluted will apply this patch
to the context of the name that was passed in.

`ctx_name` a Symbol that is the name of the context
Should be unique per `apply` block
"""
function code_for_apply_patch(ctx_name, patch)
    @capture(patch.signature,
        (fname_(args__; kwargs__)) |
        (fname_(args__))
    ) || error("Invalid patch signature: `$(patch.signature)`")



    # This is the basic parts of any cassette execture defenition  AST

    if kwargs === nothing
        method_head = Expr(
            :call,
            :(Cassette.execute),
            :(::$ctx_name), # Context
            :(::typeof($fname)), # Function
            args...)
    else
        sig_params = patch.signature.args[2:end] # Important: this is a copy
        #@show sig_params
        @assert sig_params[1].head == :parameters
        # sig_params[1] is the kwargs stuff
        # sig_params[2:end] are the normal/optional arguments
        # We need to splice in the Cassette suff before there
        insert!(sig_params, 2, :(::$ctx_name)) # Context
        insert!(sig_params, 3, :(::typeof($fname))) # Function

        method_head = Expr(
            :call,
            :(Cassette.execute),
            sig_params...
        )
    end

    # This boils down to
    # Cassette.execute(::$ContextName, ::typeof($functionname), args...) = body(args...)
    # but we have to get the types and numbers and names of arguments all in there right
    return quote
        $(method_head) = $(code_for_invoke_body(patch))

        $(code_for_kwarg_execute_overload(fname))
    end
end

"""
    code_for_invoke_body(patch)

Generates the AST to call the patches body with the correctly named arguments.
"""
function code_for_invoke_body(patch)
    call_params = call_parameters(patch.signature)
    return Expr(:call, patch.body, call_params...)
end


function code_for_kwarg_execute_overload(fname)
    # Keyword arguments see https://github.com/jrevels/Cassette.jl/issues/48#issuecomment-440605481

    quote
        function Cassette.execute(
            ctx::Cassette.Context,
            ::Core.kwftype(typeof($fname)),
            kwargs::Any,
            ::typeof($fname),
            args...
        )
            Cassette.execute(ctx, $fname, args...; kwargs...)
        end
    end
end
