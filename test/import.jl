import Compat: Dates
import Compat: read

# Patches should allow using imported bindings in the body of the patch
@testset "imported binding in body" begin
    @test_throws UndefVarError Minute
    @test isdefined(Dates, :Minute)
    import Dates: Minute, Hour

    myminute(x::Integer) = Minute(x)

    # Patches should work when referencing bindings imported in the file where the patch
    # is created.
    patch = @patch myminute(x::Integer) = Minute(Hour(x))
    apply(patch) do
        @test (@mock myminute(5)) == Minute(300)
    end
end

# Patches should allow using <module>.<binding> syntax in the signature
@testset "qualified binding in signature" begin
    @test_throws UndefVarError AbstractCmd
    @test isdefined(Base, :AbstractCmd)

    patch = @patch read(cmd::Base.AbstractCmd, ::Type{String}) = "bar"
    apply(patch) do
        @test (@mock read(`foo`, String)) == "bar"
    end
end

# Patches should allow using imported bindings syntax in the signature
@testset "imported binding in signature" begin
    import Base: AbstractCmd

    patch = @patch read(cmd::AbstractCmd, ::Type{String}) = "bar"
    apply(patch) do
        @test (@mock read(`foo`, String)) == "bar"
    end
end
