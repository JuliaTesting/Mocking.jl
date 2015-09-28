module Patch

export Original, Mock, patch

module Original
end

include("signature.jl")

type Mock
    original::Function
    replacement::Function  # only non-generic functions
    signature::Type

    function Mock(original::Function, replacement::Function, signature::Type=Void)
        if !isgeneric(replacement)
            signature = signature(replacement)
        elseif signature != Void
            m = methods(replacement, signature)
            if length(m) == 1
                replacement = m[1].func
            elseif length(m) == 0
                error("no matching methods in replacement function")
            else
                error("method is ambigious; please make signature more specific")
            end
        else
            error("signature is required when replacement is a generic function")
        end

        new(original, replacement, signature)
    end
end

patch(body::Function, mocks::Array{Mock}) = patch(body, mocks...)

function patch(body::Function, mocks::Mock...)
    if length(mocks) > 0
        patch(mocks[1]) do
            if length(mocks) > 1
                patch(body, mocks[2:end]...)
            else
                body()
            end
        end
    else
        body()
    end
end

function patch(body::Function, mock::Mock)
    patch(body, mock.original, mock.replacement, mock.signature)
end

function patch(body::Function, old_func::Function, new_func::Function, sig::Type=Void)
    if !isgeneric(new_func)
        sig = signature(new_func)
    end

    backup(old_func, sig) do
        override(body, old_func, new_func, sig)
    end
end

function backup(body::Function, new_func::Function, sig::Type=Void)
    name = Base.function_name(new_func)
    if !isgeneric(new_func)
        sig = signature(new_func)
    elseif sig == Void
        error("explicit signature is required for generic functions")
    end
    # TODO: Generate this as just an expression
    expr = parse("$name(" * join(["::$t" for t in array(sig)], ",") * ") = nothing")
    const org_func = Original.eval(expr)
    return override(body, org_func, new_func, sig)
end


function override(body::Function, old_func::Function, new_func::Function, sig::Type=Void)
    if !isgeneric(new_func)
        sig = signature(new_func)
    elseif sig != Void
        m = methods(new_func, sig)
        if length(m) == 1
            new_func = m[1].func
        elseif length(m) == 0
            error("explicit signature does not match any method")
        else
            error("explicit signature is ambigious; please make signature more specific")
        end
    else
        error("explicit signature required when replacement is a generic function")
    end

    # Replace the old Function with the new anonymous Function
    if isgeneric(old_func)
        m = methods(old_func, sig)
        if length(m) == 1
            method = m[1]
        elseif length(m) == 0
            error("function signature does not exist")
        else
            error("ambigious function signature; please make signature more specific")
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
    sig = old_method.sig

    # Overwrite a method such that Julia calls the updated function.
    # TODO: Generate this with only expressions
    isdefined(mod, name) || throw(MethodError("method $name does not exist in module $mod"))
    expr = parse("$name(" * join(["::$t" for t in array(sig)], ",") * ") = nothing")

    org_func = old_method.func
    mod.eval(expr)  # Causes warning
    old_method.func = new_func

    try
        return body()
    finally
        mod.eval(expr)  # Causes warning
        old_method.func = org_func
    end
end

end # module
