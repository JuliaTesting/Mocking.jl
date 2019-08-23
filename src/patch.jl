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
    return esc(:(Mocking.Patch($target, $alternate)))
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

function apply!(pe::PatchEnv, p::Patch)
    alternate_funcs = get!(Vector{Function}, pe.mapping, p.target)
    push!(alternate_funcs, p.alternate)
    return pe
end

function apply!(pe::PatchEnv, patches)
    for p in patches
        apply!(pe, p)
    end
end

function apply(::Injector{:MockMacro}, body::Function, pe::PatchEnv)
    prev_pe = get_active_env()
    set_active_env(pe)
    try
        return body()
    finally
        set_active_env(prev_pe)
    end
end

function apply(body::Function, patches; debug::Bool=false)
    return apply(body, PatchEnv(patches, debug))
end

const PATCH_ENV = Ref{PatchEnv}(PatchEnv())
set_active_env(pe::PatchEnv) = (PATCH_ENV[] = pe)
get_active_env() = PATCH_ENV[]
