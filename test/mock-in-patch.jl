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

    apply(patches) do
        @test (@mock foo(1.6)) == 2.0
        @test (@mock foo([1.6])) == [1.0]  # Ends up calling original function
    end

    # Create a set of patches where @mock is used within a @patch
    patches = Patch[
        @patch foo(arr::AbstractArray{Float64}) = map(x -> (@mock foo(x)), arr)
        @patch foo(x::Float64) = ceil(x)
    ]

    apply(patches) do
        @test (@mock foo(1.6)) == 2.0
        @test (@mock foo([1.6])) == [2.0]
    end
end
