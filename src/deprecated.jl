import Base: @deprecate_binding, @deprecate

# BEGIN Mocking 0.4 deprecations

@deprecate_binding PRECOMPILE_FLAG COMPILED_MODULES_FLAG false
@deprecate_binding PRECOMPILE_FIELD COMPILED_MODULES_FIELD false

@deprecate_binding DISABLE_PRECOMPILE_STR DISABLE_COMPILED_MODULES_STR
@deprecate_binding DISABLE_PRECOMPILE_CMD DISABLE_COMPILED_MODULES_CMD

@deprecate is_precompile_enabled compiled_modules_enabled false
@deprecate use_precompile set_compiled_modules false

# END Mocking 0.4 deprecations
