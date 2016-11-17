using Mocking
Mocking.enable()

using Base.Test
import Mocking: apply

include("expr.jl")
include("patch.jl")

include("concept.jl")
include("scope.jl")
include("closure.jl")
include("import.jl")
include("real-open.jl")
include("real-isfile.jl")
include("real-nested.jl")
include("mock-in-patch.jl")
include("readme.jl")
include("optional.jl")
