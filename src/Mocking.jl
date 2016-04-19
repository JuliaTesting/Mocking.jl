module Mocking

export Original, Patch, mend, @mendable

baremodule Original
end

include("signature.jl")
include("mendable.jl")
include("util.jl")
include("exception.jl")

immutable Patch
    original::Function
    replacement::Function
    signature::Signature

    function Patch(original::Function, replacement::Function, signature::Signature)
        m = methods(replacement, signature)
        if length(m) == 1
            return new(original, replacement, signature)
        elseif length(m) == 0
            error("explicit signature does not match any method")
        else
            error("explicit signature is ambigious; please make signature more specific")
        end
    end
end

function Patch(original::Function, replacement::Function)
    m = methods(replacement)
    if length(m) == 1
        signature = Signature(first(m))
    elseif length(m) == 0
        error("generic function doesn't contain any methods")
    else
        error("explicit signature required since replacement $replacement is a generic function with more than one method")
    end
    Patch(original, replacement, signature)
end

function Patch(original::Function, replacement::Function, signature::ANY)
    Patch(original, replacement, Signature(signature))
end

function mend(body::Function, patches::Array{Patch})
    if length(patches) > 0
        mend(patches[1]) do
            if length(patches) > 1
                mend(body, patches[2:end])
            else
                body()
            end
        end
    else
        body()
    end
end

mend(body::Function, patches::Patch...) = mend(body, Patch[patches...])

function mend(body::Function, patch::Patch)
    mend(body, patch.original, patch.replacement, patch.signature)
end

function mend(body::Function, old_func::Function, new_func::Function)
    m = methods(new_func)
    if length(m) == 1
        signature = Signature(first(m))
    elseif length(m) == 0
        error("generic function doesn't contain any methods")
    else
        error("explicit signature required since replacement $new_func is a generic function with more than one method")
    end
    mend(body, old_func, new_func, signature)
end

function mend(body::Function, old_func::Function, new_func::Function, signature::Signature)
    backup(old_func, signature) do
        override(body, old_func, new_func, signature)
    end
end

function mend(body::Function, old_func::Function, new_func::Function, signature::ANY)
    mend(body, old_func, new_func, Signature(signature))
end

function backup(body::Function, org_func::Function, signature::Signature)
    name = Base.function_name(org_func)
    types = [:(::$t) for t in signature.types]
    expr = :($name($(types...)) = nothing)
    backup_func = ignore_stderr() do
        Core.eval(Original, expr)
    end
    return override(body, backup_func, org_func, signature)
end


function override(body::Function, old_func::Function, new_func::Function)
    m = methods(new_func)
    if length(m) == 1
        signature = Signature(first(m))
    elseif length(m) == 0
        error("generic function doesn't contain any methods")
    else
        error("explicit signature required since replacement $new_func is a generic function with more than one method")
    end
    override(body, old_func, new_func, signature)
end

function override(body::Function, old_func::Function, new_func::Function, signature::Signature)
    m = methods(new_func, signature)
    if length(m) == 1
        new_method = first(m)
    elseif length(m) == 0
        error("signature does not match any method in function $new_func")
    else
        error("signature is ambigious; please make signature more specific\n    " * join(m, "\n    ") * "\n")
    end

    m = methods(old_func, signature)
    if length(m) == 1
        old_method = first(m)
    elseif length(m) == 0
        error("function signature does not exist")
    else
        error("ambigious function signature; please make signature more specific\n    " * join(m, "\n    ") * "\n")
    end

    return override(body, old_method, new_method)
end

function override(body::Function, old_method::TypeMapEntry, new_method::TypeMapEntry)
    mod, name = module_and_name(old_method)

    # Avoid overwriting or defining a method for a function that doesn't exist in the module
    isdefined(mod, name) || throw(FunctionError(mod, name))

    # Overwrite a method such that Julia calls the updated function
    types = [:(::$t) for t in Signature(old_method).types]
    expr = :($name($(types...)) = nothing)

    # Save the original implementation prior to modifying it
    org_impl = old_method.func

    # Ignore warning "Method definition ... overwritten"
    ignore_stderr() do
        Core.eval(mod, expr)
    end

    # Replace implementation
    old_method.func = new_method.func

    try
        return body()
    finally
        # Ignore warning "Method definition ... overwritten"
        ignore_stderr() do
            Core.eval(mod, expr)
        end
        old_method.func = org_impl
    end
end

end # module
