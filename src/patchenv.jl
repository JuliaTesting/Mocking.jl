
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
