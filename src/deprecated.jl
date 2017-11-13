import Base: @deprecate_binding

# BEGIN Mocking 0.4 deprecations

@deprecate_binding PRECOMPILE_FLAG COMPILE_MODULES_FLAG false
@deprecate_binding PRECOMPILE_FIELD COMPILE_MODULES_FIELD false

@deprecate_binding DISABLE_PRECOMPILE_STR DISABLE_COMPILE_MODULES_STR
@deprecate_binding DISABLE_PRECOMPILE_CMD DISABLE_COMPILE_MODULES_CMD

# END Mocking 0.4 deprecations
