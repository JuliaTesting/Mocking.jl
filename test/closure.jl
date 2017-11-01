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
