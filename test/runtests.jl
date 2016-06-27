# Note: Explicitly setting JULIA_TEST should only be needed on Julia 0.4
withenv("JULIA_TEST" => 1) do
    using Mocking
    using Base.Test
    import Mocking: apply

    include("concept.jl")
    include("scope.jl")
    include("closure.jl")
    include("import.jl")
    include("real-open.jl")
    include("real-isfile.jl")
    include("real-nested.jl")
end
