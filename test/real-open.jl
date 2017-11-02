import Compat: read

@testset "open" begin
    # Ensure that open cannot find the file "foo"
    @test !isfile("foo")
    @test_throws SystemError open("foo")

    # Note that patches always have higher precedence. The patch `open(::Any)`
    # will be preferred over the original `open(::AbstractString)` for `open("foo")`
    patch = @patch open(name) = IOBuffer("bar")
    apply(patch) do
        @test read((@mock open("foo")), String) == "bar"

        # The `open(::Any)` patch could result in unintended (or intended) consequences
        @test read((@mock open(`echo helloworld`)), String) == "bar"
    end

    # Better to be specific with your patches
    patch = @patch open(name::AbstractString) = IOBuffer("bar")
    apply(patch) do
        @test read((@mock open("foo")), String) == "bar"

        # The more specific `open(::AbstractString)` patches only a single method
        result = @mock open(`echo helloworld`)
        if VERSION >= v"0.7.0-DEV.3"
            io = result
        else
            io, pobj = result
        end
        @test read(io, String) == "helloworld\n"
    end
end
