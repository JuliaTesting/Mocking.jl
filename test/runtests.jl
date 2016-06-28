# Note: Explicitly setting JULIA_ENV should only be needed on Julia 0.4
# The environmental variable will only be set for the current Julia session
ENV["JULIA_ENV"] = "test"

using Mocking
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
include("optional.jl")
