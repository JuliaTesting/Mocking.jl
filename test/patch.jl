@testset "patch" begin
    @testset "unnamed function" begin
        @test_throws LoadError macroexpand(@__MODULE__, :(@patch () -> nothing))
    end

    @testset "non-function definition" begin
        @test_throws LoadError macroexpand(@__MODULE__, :(@patch f()))
    end

    @testset "non-function definition" begin
        f() = 1
        p = @patch f() = 2
        @test p.target() == 1
        @test p.alternate() == 2
    end
end
