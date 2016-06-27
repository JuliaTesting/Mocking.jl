import Compat: readstring

let
    # Ensure that open cannot find the file "foo"
    @test !isfile("foo")
    @test_throws SystemError open("foo")

    # Note that patches always have higher precedence. The patch `open(::Any)`
    # will be preferred over the original `open(::AbstractString)` for `open("foo")`
    patch = @patch open(name) = IOBuffer("bar")
    apply(patch) do
        @test readstring(@mock open("foo")) == "bar"

        # The `open(::Any)` patch could result in unintended (or intended) consequences
        @test readstring(@mock open(`echo helloworld`)) == "bar"
    end

    # Better to be specific with your patches
    patch = @patch open(name::AbstractString) = IOBuffer("bar")
    apply(patch) do
        @test readstring(@mock open("foo")) == "bar"

        # The more specific `open(::AbstractString)` patches only a single method
        io, pobj = (@mock open(`echo helloworld`))
        @test readstring(io) == "helloworld\n"
    end
end
