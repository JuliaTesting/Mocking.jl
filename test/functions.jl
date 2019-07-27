@testset "closure" begin
    magic(x) = false
    sentinel = gensym("sentinel")
    @test magic(sentinel) == false

    # Getting closers to work means having a function created in the current scope
    patch = @patch magic(x) = x == sentinel
    apply(patch) do
        @test (@mock magic(sentinel)) == true
    end
end

# https://github.com/invenia/Mocking.jl/issues/56
@testset "kwarg default uses arg" begin
    function f end

    p = @patch function f(x; y=x)
        (x, x, y, y)
    end

    apply(p) do
        @test (@mock f(1)) == (1, 1, 1, 1)
        @test (@mock f(1, y=2)) == (1, 1, 2, 2)
    end
end

# https://github.com/invenia/Mocking.jl/issues/57
@testset "kwarg default uses symbol" begin
    function f end

    p = @patch function f(x; y=:foo)
        (x, x, y, y)
    end

    apply(p) do
        @test (@mock f(1)) == (1, 1, :foo, :foo)
        @test (@mock f(1, y=2)) == (1, 1, 2, 2)
    end
end
