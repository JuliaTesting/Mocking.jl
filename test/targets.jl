# Test that Mocking can interact with functions defined at different scopes or externally

# Global scope
global_scope() = "org"

# The @mock macro is essentially a no-op
@test (@mock global_scope()) == global_scope()

# Create a patched version of function
global_patch = (@patch global_scope() = "alt")
apply(global_patch) do
    @test (@mock global_scope()) != global_scope()
end

# The @mock macro should return to the original behaviour
@test (@mock global_scope()) == global_scope()

# Local scope within a function
function test_function_scope()
    function_scope() = "org"
    @test (@mock function_scope()) == function_scope()

    patch = @patch function_scope() = "alt"
    apply(patch) do
        @test (@mock function_scope()) != function_scope()
    end

    @test (@mock function_scope()) == function_scope()
end

test_function_scope()

# Local scope within a let-block
let let_scope
    let_scope() = "org"
    @test (@mock let_scope()) == let_scope()

    patch = @patch let_scope() = "alt"
    apply(patch) do
        @test (@mock let_scope()) != let_scope()
    end

    @test (@mock let_scope()) == let_scope()
end

@testset "qualified function" begin
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

@testset "constructor function" begin
    @test Vector() == []

    p = @patch Vector() = [1,2,3]
    apply(p) do
        # Call alternative
        @test (@mock Vector()) == [1,2,3]
        @test (@mock Base.Vector()) == [1,2,3]

        # Call original function
        @test (@mock Base.Vector{Any}()) == Any[]
    end
end
