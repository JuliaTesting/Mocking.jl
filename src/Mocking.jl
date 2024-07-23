module Mocking

using Compat: mergewith
using ExprTools: splitdef, combinedef

# Available in Julia 1.11+: https://github.com/JuliaLang/julia/pull/50958
# We cannot use ScopedValues.jl for backwards compatability as that implementation breaks
# `@test_logs`.
if VERSION >= v"1.11.0-DEV.482"
    using Base: ScopedValue, with
end

export @patch, @mock, Patch, apply

include("expr.jl")
include("dispatch.jl")
include("debug.jl")
include("patch.jl")
include("mock.jl")

# Create the initial definition of `activated` which defaults having Mocking be deactivated.
# We utilize method invalidation as a feature here to allow functions using `@mock` to be
# automatically re-compiled after Mocking was activated.
#
# We slightly abuse multiple-dispatch here so that we avoid having a "method definition
# overwritten" for the first call to `Mocking.activate`. By defining a more specific method
# we avoid the warning but can still trigger invalidation.
_activated(::Integer) = false

"""
    Mocking.activated() -> Bool

Indicates if Mocking has been activated or not via `Mocking.activate`.
"""
activated() = _activated(0)

"""
    Mocking.activate() -> Nothing

Activates `@mock` call sites to allow for calling patches instead of the original function.
Intended to be called within a packages `test/runtests.jl` file.

!!! note
    Calling this causes functions which use `@mock` to become invalidated and re-compiled
    the next time they are called.
"""
function activate()
    # Avoid redefining `_activated` when it's already set appropriately
    !activated() && @eval _activated(::Int) = true
    return nothing
end

const NULLIFIED = Ref{Bool}(false)

"""
    Mocking.nullify() -> Nothing

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
