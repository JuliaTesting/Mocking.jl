module Mocking

export @patch, @mock, Patch, apply

include("expr.jl")
include("dispatch.jl")
include("patch.jl")
include("mock.jl")
include("deprecated.jl")

# Create the initial definition of `activated` which defaults Mocking to be disabled
activated() = false

"""
    Mocking.activate()

Enable `@mock` call sites to allow for calling patches instead of the original function.
"""
function activate()
    # Avoid redefining `activated` when it's already set appropriately
    !activated() && @eval activated() = true
    return nothing
end

"""
    Mocking.deactivate()

Disable `@mock` call sites to only call the original function.
"""
function deactivate()
    # Avoid redefining `activated` when it's already set appropriately
    activated() && @eval activated() = false
    return nothing
end

end # module
