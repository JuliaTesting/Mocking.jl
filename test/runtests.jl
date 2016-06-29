using Mocking

# Note: Explicitly setting Mocking.ENABLE should only be needed on Julia 0.4
if VERSION < v"0.5-"
    Mocking.enable()
end

using Base.Test
import Mocking: apply

include("expr.jl")

include("concept.jl")
include("scope.jl")
include("closure.jl")
include("import.jl")
include("real-open.jl")
include("real-isfile.jl")
include("real-nested.jl")
include("readme.jl")
include("optional.jl")
