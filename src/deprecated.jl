function ismocked(pe::PatchEnv, func_name::Symbol, args::Tuple)
    Base.depwarn("`Mocking.ismocked` is no longer used and can be safely removed.", :ismocked)
    return false
end
