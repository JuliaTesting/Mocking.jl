module Mocking

export @patch, @mock, Patch, apply,
    DISABLE_COMPILED_MODULES_STR, DISABLE_COMPILED_MODULES_CMD

include("expr.jl")
include("dispatch.jl")
include("options.jl")
include("patch.jl")
include("mock.jl")
include("deprecated.jl")

# When ENABLED is false the @mock macro is a noop.
global ENABLED = false
global PATCH_ENV = nothing

function enable(; force::Bool=false)
    ENABLED::Bool && return  # Abend early if enabled has already been set
    global ENABLED = true
    global PATCH_ENV = PatchEnv()

    if compiled_modules_enabled()
        if force
            # Disable using compiled modules when Mocking is enabled
            set_compiled_modules(false)
        else
            @warn(
                "Mocking.jl will probably not work when $COMPILED_MODULES_FLAG is ",
                "enabled. Please start `julia` with `$DISABLE_COMPILED_MODULES_STR` ",
                "or alternatively call `Mocking.enable(force=true).`",
            )
        end
    end
end

set_active_env(pe::PatchEnv) = (global PATCH_ENV = pe)
get_active_env() = PATCH_ENV::PatchEnv

end # module
