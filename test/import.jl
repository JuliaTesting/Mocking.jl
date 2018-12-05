# Patches should allow using <module>.<binding> syntax in the signature
@testset "qualified binding in signature" begin
    @test_throws UndefVarError AbstractCmd
    @test isdefined(Base, :AbstractCmd)

    patch = @patch read(cmd::Base.AbstractCmd, ::Type{String}) = "bar"
    apply(patch) do
        @test read(`foo`, String) == "bar"
    end
end

# Patches should allow using imported bindings syntax in the signature
@testset "imported binding in signature" begin
    import Base: AbstractCmd

    patch = @patch read(cmd::AbstractCmd, ::Type{String}) = "bar"
    apply(patch) do
        @test read(`foo`, String) == "bar"
    end
end
