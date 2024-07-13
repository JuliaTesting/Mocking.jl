@testset "nested mock call" begin
    function readfile(filename)
        return (@mock isfile(filename)) ? read((@mock open(filename)), String) : ""
    end

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
