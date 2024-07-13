# Depending on how the internals of `@patch` and `apply` are setup there could be issues
# with reusing a patch for a variety of reasons. These were discovered with experimenting
# with using Cassette with Mocking.

@testset "patch reuse" begin
    @testset "identical signature" begin
        # Declare the original function
        f() = 0

        # Create a patch `p1` and use it
        p1 = @patch f() = 1
        apply(p1) do
            @test (@mock f()) == 1
        end

        # Create another patch `p2` with the same function signature as `p1`
        p2 = @patch f() = 2
        apply(p2) do
            @test (@mock f()) == 2
        end

        # Verify we can re-use the `p1` patch
        apply(p1) do
            @test (@mock f()) == 1
        end
    end

    @testset "optional arguments" begin
        f(args::T...) where {T} = zero(T)

        # Create a patch function that contains two methods: `f(x)` and `f(x, y)`
        p1 = @patch f(x, y=0) = x + y
        apply(p1) do
            @test (@mock f(5)) == 5
        end

        # Create a second patch which could possibly interfere with `f(x)` from `p1` later
        p2 = @patch f(x) = -x
        apply(p2) do
            @test (@mock f(5)) == -5
        end

        # Validate that executing `f(x)` executes `f(x, 0)`
        apply(p1) do
            @test (@mock f(5)) == 5
        end
    end

    @testset "specificity" begin
        f(::Real) = Real

        # Create our initial patch
        p1 = @patch f(::Number) = Number
        apply(p1) do
            @test (@mock f(1)) == Number
        end

        # Create a second patch which is more specific than the first
        p2 = @patch f(::Integer) = Integer
        apply(p2) do
            @test (@mock f(1)) == Integer
        end

        # Validate that first patch is called and not the more specific second patch
        apply(p1) do
            @test (@mock f(1)) == Number
        end
    end
end
