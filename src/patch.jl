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
    #TODO move all this setup into the patch constructor/macro
    @capture(patch.signature,
        (name_(args__; kwargs__)) |
        (name_(args__))
    ) || error("Invalid patch signature: `$(patch.signature)`")


    params = call_parameters(patch.signature)
    invoke_body = Expr(:call, patch.body, params...)

    return Expr(
        :(=),
        Expr(
            :call,
            :(Cassette.execute),
            :(::$ctx_name), # Context
            :(::typeof($name)), # function
            #kwargs::Any, #Keyword arguments see https://github.com/jrevels/Cassette.jl/issues/48#issuecomment-440605481
            args..., #sig
        ),
        invoke_body
    )
end
