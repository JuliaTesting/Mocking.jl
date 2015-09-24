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

# function patch(fn::Function, mod::Module, name::Symbol, rep::Function)
#     const old = mod.eval(name)
#     if isgeneric(old) && isconst(mod, name)
#         if !isgeneric(rep)
#             patch(old, :env, nothing) do
#                 patch(old, :fptr, rep.fptr) do
#                     old.code = rep.code
#                     return fn()
#                 end
#             end
#         else
#             patch(old, :env, rep.env) do
#                 return patch(fn, old, :fptr, rep.fptr)
#             end
#         end
#     else
#         return applypatch(fn, mod, name, rep)
#     end
# end

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

function override(old_func::Function, new_func::Function, sig::Type=Void)
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
            m[1].func = new_func
        elseif length(m) == 0
            error("function signature does not exist")
        else
            error("ambigious function signature; please make signature more specific")
        end
    else
        old_func.fptr = new_func.fptr
        old_func.env = nothing
        old_func.code = new_func.code
    end
    nothing
end

function backup(new_func::Function, sig::Type=Void)
    name = Base.function_name(new_func)
    if !isgeneric(new_func)
        sig = signature(new_func)
    elseif sig == Void
        error("explicit signature is required for generic functions")
    end
    # TODO: Generate this as just an expression
    expr = parse("$name(" * join(["::$t" for t in array(sig)], ",") * ") = nothing")
    const org_func = Original.eval(expr)
    override(org_func, new_func, sig)
end

end # module
