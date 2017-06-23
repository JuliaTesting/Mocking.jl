function genmod()
    Core.eval(:(module $(gensym()) end))
end

macro valid_method(expr)
    result = quote
        try
            !isempty(methods(eval(genmod(), $(esc(expr)))))
        catch
            false
        end
    end
    Base.remove_linenums!(result)
    return result
end

include("ingest_parametric.jl")
include("ingest_assertion.jl")
include("ingest_default.jl")
include("ingest_parameter.jl")
include("ingest_signature.jl")
VERSION >= v"0.6" && include("ingest_signature_0.6.jl")
