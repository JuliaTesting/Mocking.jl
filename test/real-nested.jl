import Compat: read

@testset "nested mock call" begin
    readfile(filename) = (@mock isfile(filename)) ? read((@mock open(filename)), String) : ""

    # Testing with both generic and anonymous functions
    patches = Patch[
        @patch isfile(f::AbstractString) = f == "foo"
        @patch open(f::AbstractString) = IOBuffer("bar")
    ]

    @test readfile("foo") == ""

    apply(patches) do
        @test readfile("foo") == "bar"
    end

    @test readfile("foo") == ""
end
