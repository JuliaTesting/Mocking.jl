# Test that @mock works within the context of a patch.
#
# WARNING: Do not use the following code as a template as this test is for illustration
# purposes only. Typically the way this problem is handled is by using `@mock foo(...)`
# within the original function declaration of `foo(::AbstractArray)`.
@testset "mock in patch" begin
    foo(arr::AbstractArray{Float64}) = map(foo, arr)  # Typically foo should use @mock here
    foo(x::Float64) = floor(x)

    # Patching only the function that takes a scalar
    patches = Patch[
        @patch foo(x::Float64) = ceil(x)
    ]

    @test (@mock foo(1.6)) == 1.0

    # NOTE: The last test will always fail as a demonstration of how slowly overdub is when
    # executed over `@test`
    if INDIVIDUAL
        @test apply(() -> (@mock foo(1.6)), patches) == 2.0
        @test apply(() -> (@mock foo([1.6])), patches) == [3.0]  # Always fails
    else
        apply(patches) do
            @test (@mock foo(1.6)) == 2.0
            @test (@mock foo([1.6])) == [3.0]    # Always fails
        end
    end

    # # Create a set of patches where @mock is used within a @patch
    # patches = Patch[
    #     @patch foo(arr::AbstractArray{Float64}) = map(x -> (@mock foo(x)), arr)
    #     @patch foo(x::Float64) = ceil(x)
    # ]

    # apply(patches) do
    #     @test (@mock foo(1.6)) == 2.0
    #     @test (@mock foo([1.6])) == [2.0]
    # end
end

# https://github.com/invenia/Mocking.jl/issues/59
# @testset "patch calls patch" begin
#     f(args...) = 0

#     patches = [
#        @patch f(a::Function, b) = b
#        @patch f(b) = @mock f(() -> nothing, b)
#     ]

#     # apply(patches) do
#     #     @test (@mock f(identity, 1)) == 1
#     #     @test (@mock f(1)) == 1
#     # end

#     @test apply(() -> f(identity, 1), patches) == 1
#     @test apply(() -> f(1), patches) == 1
# end
