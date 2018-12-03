#| Test the basic concept behind call overloading
@testset "concept" begin
    multiply(x::Number) = 2x
    multiply(x::Int) = 2x - 1
    
    @test multiply(2) == 3
    @test multiply(0x2) == 0x4
    @test multiply(2//1) == 4//1

    @test multiply(2) == multiply(2)
    @test multiply(0x2) == multiply(0x2)
    @test multiply(2//1) == multiply(2//1)

    patches = Patch[
        @patch(multiply(x::Integer) = 3x),
        @patch(multiply(x::Int) = 4x)
    ]

    pe = Mocking.PatchEnv()
    for p in patches
        @show p
        Mocking.apply!(pe, p)
    end

    apply(pe) do
        @test multiply(2) == 8        # calls mocked `multiply(::Int)`
        @test multiply(0x2) == 0x6    # calls mocked `multiply(::Integer)`
        @test multiply(2//1) == 4//1  # calls original `multiply(::Number)`
    end
        
    # Clean env

    # Ensure that original behaviour is restored
    @test multiply(2) == 3
    @test multiply(0x2) == 0x4
    @test multiply(2//1) == 4//1

    # Use convenient syntax
    apply(patches) do
        @test multiply(2) == 8
        @test multiply(0x2) == 0x6
        @test multiply(2//1) == 4//1
    end

    # Patches should only be applied for the scope of the do block
    @test multiply(2) == 3
    @test multiply(0x2) == 0x4
    @test multiply(2//1) == 4//1
end
