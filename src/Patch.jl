module Patch

type Patch
    mod::Module
    name::Symbol
    rep::Function
end

patch(fn::Function, patches::Array{Patch}) = patch(fn, patches...)

function patch(fn::Function, patches::Patch...)
    if length(patches) > 0
        patch(patches[1]) do
            if length(patches) > 1
                patch(fn, patches[2:end]...)
            else
                fn()
            end
        end
    else
        fn()
    end
end

function patch(fn::Function, p::Patch)
    patch(p.mod, p.name, p.rep) do
        fn()
    end
end

function patch(fn::Function, mod::Module, name::Symbol, rep::Function)
    const old = mod.eval(name)
    if isgeneric(old) && isconst(mod, name)
        if !isgeneric(rep)
            patch(old, :env, nothing) do
                patch(old, :fptr, rep.fptr) do
                    old.code = rep.code
                    return fn()
                end
            end
        else
            patch(old, :env, rep.env) do
                return patch(fn, old, :fptr, rep.fptr)
            end
        end
    else
        return applypatch(fn, mod, name, rep)
    end
end

patch(fn::Function, obj::Any, name::Symbol, rep::Any) = applypatch(fn, Core, :($obj.$name), rep)
patch(fn::Function, mod::Module, name::Symbol, rep::Any) = applypatch(fn, mod, name, rep)

function applypatch(fn::Function, mod::Module, name::Union{Expr,Symbol}, rep::Any)
    const old = mod.eval(name)
    mod.eval(:($name = $rep))
    try
        fn()
    finally
        mod.eval(:($name = $old))
    end
end

end # module
