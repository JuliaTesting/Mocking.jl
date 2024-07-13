@testset "patch" begin
    @testset "unnamed function" begin
        exception = VERSION >= v"1.7" ? ArgumentError : LoadError
        @test_throws exception macroexpand(@__MODULE__, :(@patch () -> nothing))
    end

    @testset "non-function definition" begin
        exception = VERSION >= v"1.7" ? ArgumentError : LoadError
        @test_throws exception macroexpand(@__MODULE__, :(@patch f()))
    end

    @testset "empty-function definition" begin
        exception = VERSION >= v"1.7" ? ArgumentError : LoadError
        @test_throws exception macroexpand(@__MODULE__, :(@patch function f end))
    end

    @testset "non-function definition" begin
        f() = 1
        p = @patch f() = 2
        @test p.target() == 1
        @test p.alternate() == 2
    end
end
