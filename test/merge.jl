@testset "merge PatchEnv instances" begin
    multiply(x::Number) = 2x
    multiply(x::Int) = 2x - 1
    add(x::Number) = x + 2
    add(x::Int) = x + 1

    patches = Patch[
        @patch multiply(x::Integer) = 3x
        @patch multiply(x::Int) = 4x
        @patch add(x::Int) = x + 4
    ]

    @testset "simple" begin
        pe1 = Mocking.PatchEnv(patches[1])
        pe2 = Mocking.PatchEnv(patches[2:3])
        pe = Mocking.PatchEnv(patches)

        @test pe == merge(pe1, pe2)
    end

    @testset "debug flag" begin
        pe1 = Mocking.PatchEnv(patches[1], true)
        pe2 = Mocking.PatchEnv(patches[2:3])
        pe = Mocking.PatchEnv(patches, true)

        @test pe == merge(pe1, pe2)
    end
end
