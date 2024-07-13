using Base: depwarn

function ismocked(pe::PatchEnv, func_name::Symbol, args::Tuple)
    m = @__MODULE__
    depwarn("`$m.ismocked` is no longer used and can be safely removed.", :ismocked)
    return false
end

# Note: The `depwarn` call here is similar to using `@deprecate` but instead shows a fully
# qualified function name.
function enable(; force=false)
    m = @__MODULE__
    depwarn(
        "`$m.enable(; force=$force)` is deprecated, use `$m.activate()` instead.",
        :enable,
        # format trick: using this comment to force use of multiple lines
    )
    return activate()
end

function activate(f)
    m = @__MODULE__
    depwarn("`$m.activate(f)` is deprecated and will be removed in the future.", :activate)

    started_deactivated = !activated()
    try
        activate()
        Base.invokelatest(f)
    finally
        started_deactivated && deactivate()
    end
end

function deactivate()
    m = @__MODULE__
    depwarn(
        "`$m.deactivate()` is deprecated and will be removed in the future.",
        :deactivate,
        # format trick: using this comment to force use of multiple lines
    )

    # Avoid redefining `_activated` when it's already set appropriately
    Base.invokelatest(activated) && @eval _activated(::Int) = false
    return nothing
end
