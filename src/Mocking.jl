module Mocking

export @patch, @mock, Patch, apply

include("expr.jl")
include("dispatch.jl")
include("patch.jl")
include("mock.jl")
include("deprecated.jl")

const NULLIFIED = Ref{Bool}(false)
const ACTIVATED = Ref{Bool}(false)
global PATCH_ENV = PatchEnv()

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

"""
    Mocking.activate()

Enable `@mock` call sites to allow for calling patches instead of the original function.
"""
function activate()
    global ACTIVATED[] = true
    return nothing
end


set_active_env(pe::PatchEnv) = (global PATCH_ENV = pe)
get_active_env() = PATCH_ENV::PatchEnv

end # module
