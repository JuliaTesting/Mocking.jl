module Mocking

export @patch, @mock, Patch, apply

include("expr.jl")
include("dispatch.jl")
include("patch.jl")
include("mock.jl")
include("deprecated.jl")

activated() = false

"""
    Mocking.activate()

Enable `@mock` call sites to allow for calling patches instead of the original function.
"""
function activate()
    Mocking.eval(:(activated() = true))
    return nothing
end

end # module
