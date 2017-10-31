if VERSION >= v"0.7.0-DEV.1698"
    @test Mocking.is_precompile_enabled() == Bool(Base.JLOptions().use_compiled_modules)
else
    @test Mocking.is_precompile_enabled() == Bool(Base.JLOptions().use_compilecache)
end
