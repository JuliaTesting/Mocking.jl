# Name of the `julia` command-line option
const COMPILE_MODULES_FLAG = if VERSION >= v"0.7.0-DEV.1698"
    Symbol("compiled-modules")
else
    :compilecache
end

# Name of the field in the JLOptions structure which corresponds to the command-line option
const COMPILE_MODULES_FIELD = if VERSION >= v"0.7.0-DEV.1698"
    :use_compiled_modules
else
    :use_compilecache
end

const DISABLE_COMPILE_MODULES_STR = "--$COMPILE_MODULES_FLAG=no"
const DISABLE_COMPILE_MODULES_CMD = `$DISABLE_COMPILE_MODULES_STR`

# Generate a mutable version of JLOptions
let
    T = Base.JLOptions
    fields = [:($(fieldname(T,i))::$(fieldtype(T,i))) for i in 1:nfields(T)]

    @eval begin
        type JLOptionsMutable
            $(fields...)
        end
    end
end

function is_precompile_enabled()
    opts = Base.JLOptions()
    field = COMPILE_MODULES_FIELD

    # When the pre-compile field is empty it means pre-compilation is unsupported. If the
    # pre-compile field is missing that means pre-compilation to be assumed to be enabled.
    return field != Symbol() && (!isdefined(opts, field) || Bool(getfield(opts, field)))
end

"""
    use_precompile(state::Bool) -> Void

Override the Julia command line flag `--$COMPILE_MODULES_FLAG` with a runtime setting.
Code run before this the value is modified will use the original setting. Not meant for
general purpose usage.
"""
function use_precompile(state::Bool)
    value = Base.convert(Int8, state)

    # Load the C global into a mutable Julia type
    jl_options = cglobal(:jl_options, JLOptionsMutable)
    opts = unsafe_load(jl_options)

    # Avoid modifying the global when the value hasn't changed
    if getfield(opts, COMPILE_MODULES_FIELD) != value
        warn("Using experimental code which modifies jl_options global struct")
        setfield!(opts, COMPILE_MODULES_FIELD, value)
        unsafe_store!(jl_options, opts)
    end

    nothing
end
