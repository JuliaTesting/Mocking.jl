__precompile__(true)

module Mocking
using MacroTools
using Cassette
using Cassette: @context
#TODO: strip out Compat
using InteractiveUtils: hasmethod
using Base: invokelatest

include("expr.jl")
include("bindings.jl")
include("deprecated.jl")

export
    # Mocking.jl
    @patch, Patch, apply,
    # deprecated.jl
    @mock

struct Patch
    signature::Expr
    body::Function
    modules::Set
    # translation::Dict

    function Patch(signature::Expr, body::Function, translation::Dict)
        trans = adjust_bindings(translation)
        sig = name_parameters(absolute_signature(signature, trans))

        # On VERSION >= v"0.5"
        # modules = Set(b.args[1] for b in values(trans) if isa(b, Expr))
        modules = Set()
        for b in values(trans)
            if isa(b, Expr)
                push!(modules, b.args[1])
            end
        end

        new(sig, body, modules)
    end
end

# TODO: Find non-eval way to determine module locations of Types
# evaling in the @patch scope seems to be problematic for pre-compliation
# first(methods(x)).sig.types[2:end]

# We can use the @patch macro to create a list of bindings used then pass that
# in as an array into Patch. At runtime the types and function names will be fully
# qualified

# We can support optional parameters and keywords by using generic functions on
# 0.4

function convert(::Type{Expr}, p::Patch)
    exprs = Expr[]

    # Generate imports for all required modules
    for m in p.modules
        bindings = splitbinding(m)

        for i in 1:length(bindings)
            push!(exprs, Expr(:import, Expr(:., bindings[1:i]...)))
        end
    end

    # Generate the new method which will call the user's patch function. We need to perform
    # this call instead of injecting the body expression to support closures.
    sig, body = p.signature, p.body
    params = call_parameters(sig)
    push!(exprs, Expr(:(=), sig, Expr(:block, Expr(:call, body, params...))))

    return Expr(:block, exprs...)
end

macro patch(expr::Expr)
    @capture(expr,
        function name_(params__) body_ end |
        (name_(params__) = body_)
    ) || throw(ArgumentError("expression is not a function definition"))
    
    signature = Expr(:call, name, params...)

    # Determine the bindings used in the signature
    bindings = Bindings(signature)

    # Need to evaluate the body of the function in the context of the `@patch` macro in
    # order to support closures.
    # func = Expr(:(->), Expr(:tuple, params...), body)
    func = Expr(:(=), Expr(:call, gensym(), params...), body)

    # Generate a translation between the external bindings and the runtime types and
    # functions. The translation will be used to revise all bindings to be absolute.
    translations = [Expr(:call, :(=>), QuoteNode(b), b) for b in bindings.external]

    return esc(:(Mocking.Patch( $(QuoteNode(signature)), $func, Dict($(translations...)) )))
end



"""
    code_for_apply_patch(ctx_name, patch)

Returns an `Expr` that when evaluted will apply this patch
to the context of the name that was passed in.

`ctx_name` a Symbol that is the name of the context
Should be unique per `apply` block
"""
function code_for_apply_patch(ctx_name, patch)

    # Todo move all this setup into the patch constructor/macro
    @capture(patch.signature,
        (opname_(args__; kwargs__)) |
        (opname_(args__))
    ) || error("Invalid patch signature: `$(patch.signature)`")

    patch_expr = Mocking.convert(Expr, patch)
    invoke_body = patch_expr.args[end].args[end].args[end]
    
    return Expr(
        :(=),
        Expr(
            :call,
            :(Cassette.execute),
            :(:: $ctx_name), # Context
            :(::typeof($(opname))), # function
            args..., #sig
            #$(esc(patch)).kwargs..., #TODO kwargs https://github.com/jrevels/Cassette.jl/issues/48
        ),
        invoke_body
    )
end







struct PatchEnv{CTX <: Cassette.Context}
    ctx::CTX
    debug::Bool
end

function PatchEnv(debug::Bool=false)
    ctx_name = gensym(:MockEnv)
    CTX = @eval @context $(ctx_name) # declare the context
    ctx = @eval $CTX() # Get an intance of it
    PatchEnv{CTX}(ctx, debug)
end

function PatchEnv(patch, debug::Bool=false)
    pe = PatchEnv(debug)
    apply!(pe, patch)
    return pe
end

"""
    apply!(pe::PatchEnv, patch[es])

Applies the patches to the PatchEnv.

### Implememtation note:
This adds new methods to the `Cassette.execute` for the context of the PatchEnv.
"""
function apply!(pe::PatchEnv{CTX}, p::Patch) where CTX
    return eval(code_for_apply_patch(CTX, p))
end

function apply!(pe::PatchEnv, patches::Array{Patch})
    for p in patches
        apply!(pe, p)
    end
end

function apply(body::Function, pe::PatchEnv)
    return @eval Cassette.overdub($(pe.ctx), $body)
end

function apply(body::Function, patch; debug::Bool=false)
    return apply(body, PatchEnv(patch, debug))
end

function ismocked(pe::PatchEnv, func_name::Symbol, args::Tuple)
    # TODO: redefine this in terms of `methodswith(pe.ctx, Cassette.execute...)`
    # If required
    error("`ismocked` is not implemented")
end
end # module
