function genmod()
    Core.eval(@__MODULE__, :(module $(gensym()) end))
end

function valid_method(expr::Expr)
    try
        !isempty(methods(Core.eval(genmod(), expr)))
    catch
        false
    end
end

macro valid_method(expr)
    result = quote
        valid_method($(QuoteNode(expr)))
    end
    Base.remove_linenums!(result)
    return esc(result)
end

@testset "bindings" begin
    include("ingest_parametric.jl")
    include("ingest_assertion.jl")
    include("ingest_default.jl")
    include("ingest_parameter.jl")
    include("ingest_signature.jl")
end
