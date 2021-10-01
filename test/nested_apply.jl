# Nesting calls to apply should take the appropriate union of patches.
@testset "nested apply calls" begin

    multiply(x::Number) = 2x
    multiply(x::Int) = 2x - 1
    add(x::Number) = x + 2
    add(x::Int) = x + 1

    @testset "simple" begin
        patches = Patch[
            @patch multiply(x::Integer) = 3x
            @patch multiply(x::Int) = 4x
            @patch add(x::Int) = x + 4
        ]

        apply(patches) do
            @test (@mock multiply(2)) == 8
            @test (@mock multiply(0x2)) == 0x6
            @test (@mock multiply(2//1)) == 4//1
            @test (@mock add(2//1)) == 4 // 1
            @test (@mock add(2)) == 6
        end

        apply(patches[1]) do
            @test (@mock multiply(2)) == 6
            @test (@mock multiply(0x2)) == 0x6
            @test (@mock multiply(2//1)) == 4//1
            @test (@mock add(2//1)) == 4 // 1
            @test (@mock add(2)) == 3

            apply(patches[2]) do
                @test (@mock multiply(2)) == 8
                @test (@mock multiply(0x2)) == 0x6
                @test (@mock multiply(2//1)) == 4//1
                @test (@mock add(2//1)) == 4 // 1
                @test (@mock add(2)) == 3

                apply(patches[3]) do
                    @test (@mock multiply(2)) == 8
                    @test (@mock multiply(0x2)) == 0x6
                    @test (@mock multiply(2//1)) == 4//1
                    @test (@mock add(2//1)) == 4 // 1
                    @test (@mock add(2)) == 6
                end

                @test (@mock multiply(2)) == 8
                @test (@mock multiply(0x2)) == 0x6
                @test (@mock multiply(2//1)) == 4//1
                @test (@mock add(2//1)) == 4 // 1
                @test (@mock add(2)) == 3
            end

            @test (@mock multiply(2)) == 6
            @test (@mock multiply(0x2)) == 0x6
            @test (@mock multiply(2//1)) == 4//1
            @test (@mock add(2//1)) == 4 // 1
            @test (@mock add(2)) == 3
        end
    end

    @testset "repeated patch" begin
        patches = Patch[
            @patch multiply(x::Integer) = 3x
            @patch multiply(x::Integer) = 4x
        ]

        apply(patches) do
            @test (@mock multiply(2)) == 8
        end

        apply(patches[1]) do
            @test (@mock multiply(2)) == 6
            apply(patches[2]) do
                @test (@mock multiply(2)) == 8
            end
            @test (@mock multiply(2)) == 6
        end
    end
end
