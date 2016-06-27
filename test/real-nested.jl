import Compat: readstring

let
    readfile(filename) = (@mock isfile(filename)) ? readstring(@mock open(filename)) : ""

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
