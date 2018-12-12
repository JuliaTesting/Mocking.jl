struct PatchEnvName{id} <: Cassette.AbstractContextName end


struct PatchEnv{CTX <: Cassette.Context}
    ctx::CTX
    debug::Bool
end

function PatchEnv(debug::Bool=false)
    ctx = Cassette.Context(PatchEnvName{gensym(:Mocking)}())
    PatchEnv{typeof(ctx)}(ctx, debug)
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

"""
    apply(body::Function, patchenv|patch|patches)

Apply the patches for the duration of the body.
This essentially activates the patch enviroment
(which will be created if required).

Write this as

```
apply(patches) do
    @test foo(1) == "bar"
    @test foo(2) == "barbar"
end
```

Any method that is has a patch defined in `patches`
will be replaced with it's mock during the invocation of `foo`
(and the other code in the body).
"""
function apply(body::Function, pe::PatchEnv)

    return @eval Cassette.overdub($(pe.ctx), $body)
end

function apply(body::Function, patch; debug::Bool=false)
    return apply(body, PatchEnv(patch, debug))
end
