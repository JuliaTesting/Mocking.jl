using Base: @deprecate, depwarn

function ismocked(pe::PatchEnv, func_name::Symbol, args::Tuple)
    m = @__MODULE__
    depwarn("`$m.ismocked` is no longer used and can be safely removed.", :ismocked)
    return false
end

# Note: Very similar to using `@deprecate` but displays fully qualified function names
function enable(; force=false)
    m = @__MODULE__
    depwarn("`$m.enable(; force=$force)` is deprecated, use `$m.activate()` instead.", :enable)
    activate()
end

@deprecate set_active_env(f, pe) with_active_env(f, pe) false