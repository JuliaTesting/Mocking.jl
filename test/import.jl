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

@testset "qualified" begin
    # Define a new generic function named zero
    zero() = 0

    patch = @patch Base.zero(T::Type{<:Integer}) = one(T)
    apply(patch) do
        # Call alternative
        @test (@mock Base.zero(Int)) == 1

        # Call original function
        @test (@mock Base.zero(1)) == 0

        # Call new function named zero
        @test (@mock zero()) == 0
        @test_throws MethodError (@mock zero(1))
    end
end
