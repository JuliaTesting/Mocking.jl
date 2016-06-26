let magic
    magic(x) = false
    sentinel = gensym()
    @test magic(sentinel) == false

    # Closures don't work as the patch is evaluated in a different module
    patch = @patch magic(x) = x == sentinel
    apply(patch) do
        @test_throws Exception (@mock magic(sentinel))
    end

    # In the future it may be possible to make use of the interpolation syntax
    patch = @patch magic(x) = x == $sentinel
    apply(patch) do
        @test_throws Exception (@mock magic(sentinel))
    end
end
