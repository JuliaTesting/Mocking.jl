import Compat: fieldcount

# Name of the `julia` command-line option
const COMPILED_MODULES_FLAG = if VERSION >= v"0.7.0-DEV.1698"
    Symbol("compiled-modules")
else
    :compilecache
end

# Name of the field in the JLOptions structure which corresponds to the command-line option
const COMPILED_MODULES_FIELD = if VERSION >= v"0.7.0-DEV.1698"
    :use_compiled_modules
else
    :use_compilecache
end

const DISABLE_COMPILED_MODULES_STR = "--$COMPILED_MODULES_FLAG=no"
const DISABLE_COMPILED_MODULES_CMD = `$DISABLE_COMPILED_MODULES_STR`

# Generate a mutable version of JLOptions
let
    T = Base.JLOptions
    fields = [:($(fieldname(T,i))::$(fieldtype(T,i))) for i in 1:fieldcount(T)]

    @eval begin
        mutable struct JLOptionsMutable
            $(fields...)
        end
    end
end

"""
    compiled_modules_enabled() -> Bool

Determine if the `julia` command line flag `--$COMPILED_MODULES_FLAG` has been set to "yes".
"""
function compiled_modules_enabled()
    opts = Base.JLOptions()
    field = COMPILED_MODULES_FIELD

    # When the field is set to `Symbol()` it means that compiled-modules is unsupported.
    # If the compiled-modules field is undefined we assume that compiled-modules is enabled
    # by default.
    return field != Symbol() && (!isdefined(opts, field) || Bool(getfield(opts, field)))
end

"""
    set_compiled_modules(state::Bool) -> Void

Override the `julia` command line flag `--$COMPILED_MODULES_FLAG` with a runtime setting.
Code run before this the value is modified will use the original setting. Not meant for
general purpose usage.
"""
function set_compiled_modules(state::Bool)
    value = Base.convert(Int8, state)

    # Load the C global into a mutable Julia type
    jl_options = cglobal(:jl_options, JLOptionsMutable)
    opts = unsafe_load(jl_options)

    # Avoid modifying the global when the value hasn't changed
    if getfield(opts, COMPILED_MODULES_FIELD) != value
        @warn("Using experimental code which modifies jl_options global struct")
        setfield!(opts, COMPILED_MODULES_FIELD, value)
        unsafe_store!(jl_options, opts)
    end

    nothing
end
