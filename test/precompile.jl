if VERSION >= v"0.7.0-DEV.1698"
    @test Mocking.is_precompile_enabled() == Bool(Base.JLOptions().use_compiled_modules)
elseif VERSION >= v"0.5.0-dev+977"
    @test Mocking.is_precompile_enabled() == Bool(Base.JLOptions().use_compilecache)
else
    @test Mocking.is_precompile_enabled() == false
end
