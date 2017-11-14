@testset "compiled_modules_enabled" begin
    if VERSION >= v"0.7.0-DEV.1698"
        @test Mocking.compiled_modules_enabled() == Bool(Base.JLOptions().use_compiled_modules)
    else
        @test Mocking.compiled_modules_enabled() == Bool(Base.JLOptions().use_compilecache)
    end
end
