# Replacing `isfile(path...)` could be an issue due to its use of Varargs

@testset "isfile" begin
    null_file = string(@__FILE__, ".null")  # Note: tempfile() on Windows creates a file
    @test isfile(null_file) == false

    # Can't use `null_file` since closures don't currently work.
    # Note: @__FILE__ is resolved in the context of this file.
    patch = @patch isfile(p...) = first(p) == string(@__FILE__, ".null")
    apply(patch) do
        @test (@mock isfile(null_file)) == true
    end
end
