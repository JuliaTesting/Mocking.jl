# Test the basic concept behind call overloading
@testset "concept" begin
    multiply(x::Number) = 2x
    multiply(x::Int) = 2x - 1

    @test (@mock multiply(2)) == 3
    @test (@mock multiply(0x2)) == 0x4
    @test (@mock multiply(2//1)) == 4//1

    @test (@mock multiply(2)) == multiply(2)
    @test (@mock multiply(0x2)) == multiply(0x2)
    @test (@mock multiply(2//1)) == multiply(2//1)

    patches = Patch[
        @patch multiply(x::Integer) = 3x
        @patch multiply(x::Int) = 4x
    ]

    pe = Mocking.PatchEnv()
    for p in patches
        Mocking.apply!(pe, p)
    end
    Mocking.set_active_env(pe)

    @test (@mock multiply(2)) == 8        # calls mocked `multiply(::Int)`
    @test (@mock multiply(0x2)) == 0x6    # calls mocked `multiply(::Integer)`
    @test (@mock multiply(2//1)) == 4//1  # calls original `multiply(::Number)`

    @test (@mock multiply(2)) != multiply(2)
    @test (@mock multiply(0x2)) != multiply(0x2)
    @test (@mock multiply(2//1)) == multiply(2//1)

    # Clean env
    pe = Mocking.PatchEnv()
    Mocking.set_active_env(pe)

    # Ensure that original behaviour is restored
    @test (@mock multiply(2)) == 3
    @test (@mock multiply(0x2)) == 0x4
    @test (@mock multiply(2//1)) == 4//1

    # Use convenient syntax
    apply(patches) do
        @test (@mock multiply(2)) == 8
        @test (@mock multiply(0x2)) == 0x6
        @test (@mock multiply(2//1)) == 4//1
    end

    # Patches should only be applied for the scope of the do block
    @test (@mock multiply(2)) == 3
    @test (@mock multiply(0x2)) == 0x4
    @test (@mock multiply(2//1)) == 4//1
end
