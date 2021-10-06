module Mocking

using Compat: mergewith
using ContextVariablesX: @contextvar, with_context
using ExprTools: splitdef, combinedef

export @patch, @mock, Patch, apply

include("expr.jl")
include("dispatch.jl")
include("patch.jl")
include("mock.jl")
include("deprecated.jl")

# Create the initial definition of `activated` which defaults Mocking to be disabled
activated() = false

"""
    Mocking.activate([func])

Enable `@mock` call sites to allow for calling patches instead of the original function.
"""
function activate()
    # Avoid redefining `activated` when it's already set appropriately
    !activated() && @eval activated() = true
    return nothing
end

function activate(f)
    old = activated()
    try
        activate()
        Base.invokelatest(f)
    finally
        if (Base.invokelatest(activated) != old)
            @eval activated() = $old
        end
    end
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


const NULLIFIED = Ref{Bool}(false)

"""
    Mocking.nullify()

Force any packages loaded after this point to treat the `@mock` macro as a no-op. Doing so
will maximize performance by eliminating any runtime checks taking place at the `@mock` call
sites but will break any tests that require patches to be applied.

Note to ensure that all `@mock` macros are inoperative be sure to call this function before
loading any packages which depend on Mocking.jl.
"""
function nullify()
    global NULLIFIED[] = true
    return nothing
end

end # module
