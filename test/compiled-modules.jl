@testset "compiled_modules_enabled" begin
    @test Mocking.compiled_modules_enabled() == Bool(Base.JLOptions().use_compiled_modules)
end
