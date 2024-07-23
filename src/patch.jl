# `target` will typically a `Function` or `Type` but could also be a function-like object
struct Patch{T}
    target::T
    alternate::Function
end

"""
    @patch expr

Creates a patch from a function definition. A patch can be used with [`apply`](@ref) to
temporarily include the patch when performing multiple dispatch on `@mock`ed call sites.

See also: [`@mock`](@ref), [`apply`](@ref).
"""
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
    PatchEnv(mapping::AbstractDict) = new(mapping)
end

function PatchEnv(patches)
    pe = PatchEnv()
    apply!(pe, patches)
    return pe
end

PatchEnv() = PatchEnv(Dict{Any,Vector{Function}}())

function Base.:(==)(pe1::PatchEnv, pe2::PatchEnv)
    return pe1.mapping == pe2.mapping
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
"""
function Base.merge(pe1::PatchEnv, pe2::PatchEnv)
    mapping = mergewith(vcat, pe1.mapping, pe2.mapping)
    return PatchEnv(mapping)
end

function apply!(pe::PatchEnv, p::Patch)
    alternate_funcs = get!(Vector{Function}, pe.mapping, p.target)
    # isempty(alternate_funcs) && push!(alternate_funcs, p.target)
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
    apply(body::Function, patches) -> Any

Applies one or more `patches` during execution of `body`. Specifically ,any [`@mock`](@ref)
call sites encountered while running `body` will include the provided `patches` when
performing dispatch.

Multiple-dispatch is used to determine which method to call when utilizing multiple patches.
However, patch defined methods always take precedence over the original function methods.

!!! note
    Ensure you have called [`activate`](@ref) prior to calling `apply` as otherwise the
    provided patches will be ignored.

See also: [`@mock`](@ref), [`@patch`](@ref).

## Examples

Applying a patch allows the alternative patch function to be called:

```jldoctest
julia> f() = "original";

julia> p = @patch f() = "patched";

julia> apply(p) do
            @mock f()
       end
"patched"
```

Patches take precedence over the original function even when the original method is more
specific:

```jldoctest
julia> f(::Int) = "original";

julia> p = @patch f(::Any) = "patched";

julia> apply(p) do
            @mock f(1)
       end
"patched"
```

However, when the patches do not provide a valid method to call then the original function
will be used as a fallback:

```jldoctest
julia> f(::Int) = "original";

julia> p = @patch f(::Char) = "patched";

julia> apply(p) do
           @mock f(1)
       end
"original"
```

### Nesting

Nesting multiple [`apply`](@ref) calls is allowed. When multiple patches are provided for
the same method then the innermost patch takes precedence:

```jldoctest
julia> f() = "original";

julia> p1 = @patch f() = "p1";

julia> p2 = @patch f() = "p2";

julia> apply(p1) do
           apply(p2) do
               @mock f()
           end
       end
"p2"
```

When multiple patches are provided for different methods then multiple-dispatch is used to
select the most specific patch:

```jldoctest
julia> f(::Int) = "original";

julia> p1 = @patch f(::Integer) = "p1";

julia> p2 = @patch f(::Number) = "p2";

julia> apply(p1) do
           apply(p2) do
               @mock f(1)
           end
       end
"p1"
```
"""
function apply end

function apply(body::Function, pe::PatchEnv)
    merged_pe = merge(PATCH_ENV[], pe)
    return with_active_env(body, merged_pe)
end

function apply(body::Function, patches)
    return apply(body, PatchEnv(patches))
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
