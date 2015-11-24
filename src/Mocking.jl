module Mocking

export Original, Patch, mend, @mendable

baremodule Original
end

include("signature.jl")

macro mendable(expr)
    return :(eval($(Expr(:quote, expr))))
end

type Patch
    original::Function
    replacement::Function  # only non-generic functions
    signature::Signature

    function Patch(original::Function, replacement::Function, signature::Signature)
        if isgeneric(replacement)
            m = methods(replacement, signature)
            if length(m) == 1
                replacement = m[1].func
            elseif length(m) == 0
                error("explicit signature does not match any method")
            else
                error("explicit signature is ambigious; please make signature more specific")
            end
        end

        return new(original, replacement, signature)
    end
end

function Patch(original::Function, replacement::Function)
    if !isgeneric(replacement)
        signature = Signature(replacement)
    else
        m = collect(methods(replacement))
        if length(m) == 1
            signature = Signature(m[1])
        elseif length(m) == 0
            error("generic function doesn't contain any methods")
        else
            error("explicit signature required since replacement $replacement is a generic function with more than one method")
        end
    end
    Patch(original, replacement, signature)
end

function Patch(original::Function, replacement::Function, signature::ANY)
    Patch(original, replacement, Signature(signature))
end

mend(body::Function, patches::Array{Patch}) = mend(body, patches...)

function mend(body::Function, patches::Patch...)
    if length(patches) > 0
        mend(patches[1]) do
            if length(patches) > 1
                mend(body, patches[2:end]...)
            else
                body()
            end
        end
    else
        body()
    end
end

function mend(body::Function, patch::Patch)
    mend(body, patch.original, patch.replacement, patch.signature)
end

function mend(body::Function, old_func::Function, new_func::Function)
    if !isgeneric(new_func)
        signature = Signature(new_func)
    else
        m = collect(methods(new_func))
        if length(m) == 1
            signature = Signature(m[1])
        elseif length(m) == 0
            error("generic function doesn't contain any methods")
        else
            error("explicit signature required since replacement $new_func is a generic function with more than one method")
        end
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
    const backup_func = Core.eval(Original, expr)
    return override(body, backup_func, org_func, signature)
end


function override(body::Function, old_func::Function, new_func::Function)
    if !isgeneric(new_func)
        signature = Signature(new_func)
    else
        m = collect(methods(new_func))
        if length(m) == 1
            signature = Signature(m[1])
        elseif length(m) == 0
            error("generic function doesn't contain any methods")
        else
            error("explicit signature required since replacement $new_func is a generic function with more than one method")
        end
    end
    override(body, old_func, new_func, signature)
end

function override(body::Function, old_func::Function, new_func::Function, signature::Signature)
    if isgeneric(new_func)
        m = methods(new_func, signature)
        if length(m) == 1
            new_func = m[1].func
        elseif length(m) == 0
            error("signature does not match any method in function $new_func")
        else
            error("signature is ambigious; please make signature more specific\n    " * join(m, "\n    ") * "\n")
        end
    end


    # Replace the old Function with the new anonymous Function
    if isgeneric(old_func)
        m = methods(old_func, signature)
        if length(m) == 1
            method = m[1]
        elseif length(m) == 0
            error("function signature does not exist")
        else
            error("ambigious function signature; please make signature more specific\n    " * join(m, "\n    ") * "\n")
        end

        return override_internal(body, method, new_func)
    else
        return override_internal(body, old_func, new_func)
    end
end

function override_internal(body::Function, old_func::Function, new_func::Function)
    isgeneric(old_func) && error("original function cannot be a generic")
    isgeneric(new_func) && error("replacement function cannot be a generic")

    org_fptr = old_func.fptr
    org_code = old_func.code
    old_func.fptr = new_func.fptr
    old_func.code = new_func.code

    try
        return body()
    finally
        old_func.fptr = org_fptr
        old_func.code = org_code
    end
end

function override_internal(body::Function, old_method::Method, new_func::Function)
    isgeneric(new_func) && error("replacement function cannot be a generic")

    mod = old_method.func.code.module
    name = old_method.func.code.name

    # Overwrite a method such that Julia calls the updated function.
    isdefined(mod, name) || throw(MethodError("method $name does not exist in module $mod"))
    types = [:(::$t) for t in Signature(old_method).types]
    expr = :($name($(types...)) = nothing)

    org_func = old_method.func

    # Ignore warning "Method definition ... overwritten"
    ignore_stderr() do
        Core.eval(mod, expr)
    end

    old_method.func = new_func

    try
        return body()
    finally
        # Ignore warning "Method definition ... overwritten"
        ignore_stderr() do
            Core.eval(mod, expr)
        end
        old_method.func = org_func
    end
end

function ignore_stderr(body::Function)
    # TODO: Need to figure out what to do on Windows...
    @windows_only return body()

    stderr = Base.STDERR
    null = open("/dev/null", "w")
    redirect_stderr(null)
    try
        return body()
    catch
        # Note: Catch runs prior to finally but errors seem to display fine
        rethrow()
    finally
        redirect_stderr(stderr)
    end
end

end # module
