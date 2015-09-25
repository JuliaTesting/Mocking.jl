module Patch

export Original

module Original
end

include("signature.jl")

# type Patch
#     mod::Module
#     name::Symbol
#     rep::Function
# end

# patch(fn::Function, patches::Array{Patch}) = patch(fn, patches...)

# function patch(fn::Function, patches::Patch...)
#     if length(patches) > 0
#         patch(patches[1]) do
#             if length(patches) > 1
#                 patch(fn, patches[2:end]...)
#             else
#                 fn()
#             end
#         end
#     else
#         fn()
#     end
# end

# function patch(fn::Function, p::Patch)
#     patch(p.mod, p.name, p.rep) do
#         fn()
#     end
# end

function patch(body::Function, old_func::Function, new_func::Function, sig::Type=Void)
    if !isgeneric(new_func)
        sig = signature(new_func)
    end

    backup(old_func, sig) do
        override(body, old_func, new_func, sig)
    end
end

# patch(fn::Function, obj::Any, name::Symbol, rep::Any) = applypatch(fn, Core, :($obj.$name), rep)
# patch(fn::Function, mod::Module, name::Symbol, rep::Any) = applypatch(fn, mod, name, rep)

# function applypatch(fn::Function, mod::Module, name::Union{Expr,Symbol}, rep::Any)
#     const old = mod.eval(name)
#     mod.eval(:($name = $rep))
#     try
#         fn()
#     finally
#         mod.eval(:($name = $old))
#     end
# end

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
