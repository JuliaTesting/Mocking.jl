# `target` will typically a `Function` or `Type` but could also be a function-like object
struct Patch{T}
    target::T
    alternate::Function
end

macro patch(expr::Expr)
    def = splitdef(expr)

    if haskey(def, :name) && haskey(def, :body)
        target = def[:name]
    elseif !haskey(def, :name)
        throw(ArgumentError("Function definition must be a named function"))
    else
        throw(ArgumentError("Function definition must not be an empty function"))
    end

    # Include the target function name in the patch to make stack traces easier to read.
    # If the provided target uses a fully-qualified reference we'll just extract the name
    # of the function (e.g `Base.foo` -> `foo`).
    target_name = if Meta.isexpr(target, :.)
        target.args[2].value
    else
        target
    end

    def[:name] = gensym(string(target_name, "_patch"))
    alternate = combinedef(def)

    # We need to evaluate the alternate function in the context of the `@patch` macro in
    # order to support closures.
    return esc(:($Patch($target, $alternate)))
end

struct PatchEnv
    mapping::Dict{Any,Vector{Function}}
    debug::Bool
end

function PatchEnv(patches, debug::Bool=false)
    pe = PatchEnv(debug)
    apply!(pe, patches)
    return pe
end

PatchEnv(debug::Bool=false) = PatchEnv(Dict{Any,Vector{Function}}(), debug)

function Base.:(==)(pe1::PatchEnv, pe2::PatchEnv)
    return pe1.mapping == pe2.mapping && pe1.debug == pe2.debug
end

"""
    merge(pe1::PatchEnv, pe2::PatchEnv) -> PatchEnv

Merge the two `PatchEnv` instances.

This is done in such a way that the following always holds:

```
patches_1 = Patch[...]
patches_2 = Patch[...]
patches = vcat(patches_1, patches_2)

pe1 = PatchEnv(patches_1)
pe2 = PatchEnv(patches_2)
pe = PatchEnv(patches)

@assert pe == merge(pe1, pe2)
```

The `debug` flag will be set to true if either `pe1` or `pe2` have it set to true.
"""
function Base.merge(pe1::PatchEnv, pe2::PatchEnv)
    mapping = mergewith(vcat, pe1.mapping, pe2.mapping)
    return PatchEnv(mapping, pe1.debug || pe2.debug)
end

function apply!(pe::PatchEnv, p::Patch)
    alternate_funcs = get!(Vector{Function}, pe.mapping, p.target)
    push!(alternate_funcs, p.alternate)
    return pe
end

function apply!(pe::PatchEnv, patches)
    for p in patches
        apply!(pe, p)
    end
    return pe
end

"""
    apply(body::Function, patches; debug::Bool=false)
    apply(body::Function, pe::PatchEnv)

Convenience function to run `body` in the context of the given `patches`.

This is intended to be used with do-block notation, e.g.:

```
patch = @patch ...
apply(patch) do
    ...
end
```

## Nesting

Note that calls to apply will nest the patches that are applied. If multiple patches
are made to the same method, the innermost patch takes precedence.

The following two examples are equivalent:

```
patch_2 = @patch ...
apply([patch, patch_2]) do
    ...
end
```

```
apply(patch) do
    apply(patch_2) do
        ...
    end
end
```
"""
function apply(body::Function, pe::PatchEnv)
    merged_pe = merge(PATCH_ENV[], pe)
    return with_active_env(body, merged_pe)
end

function apply(body::Function, patches; debug::Bool=false)
    return apply(body, PatchEnv(patches, debug))
end

# https://github.com/JuliaLang/julia/pull/50958
if VERSION >= v"1.11.0-DEV.482"
    const PATCH_ENV = ScopedValue(PatchEnv())
    with_active_env(body::Function, pe::PatchEnv) = with(body, PATCH_ENV => pe)
else
    const PATCH_ENV = Ref{PatchEnv}(PatchEnv())

    function with_active_env(body::Function, pe::PatchEnv)
        old_pe = PATCH_ENV[]
        try
            PATCH_ENV[] = pe
            body()
        finally
            PATCH_ENV[] = old_pe
        end
    end
end
