# Use mend to override the method open(::AbstractString)
let
    # Ensure that open cannot find the file "foo"
    @test !isfile("foo")
    @test_throws SystemError open("foo")

    # The Original module provides a way to get at the original method
    replacement = (name) -> name == "foo" ? IOBuffer("bar") : Original.open(name)
    @test_throws UndefVarError Original.open  # Only defined when mend is run

    # The replacement signature is ambiguious and mend cannot determine what open method to replace
    @test_throws ErrorException mend(() -> nothing, open, replacement)
    @test isa(Original.open, Function)  # TODO: Original methods should be cleared after mend

    @test_throws SystemError open("foo")

    # Replacement is no longer ambiguious if we supply a specific signature
    mend(open, replacement, (AbstractString,)) do
        @test @mendable readstring(open("foo")) == "bar"
        @test @mendable isa(open(@__FILE__), IOStream)  # Any other file works normally
    end

    @test_throws SystemError open("foo")

    # Replacement is no longer ambiguious if the signature is included in the definition
    replacement = (name::AbstractString) -> name == "foo" ? IOBuffer("bar") : Original.open(name)
    mend(open, replacement) do
        @test @mendable readstring(open("foo")) == "bar"
        @test @mendable isa(open(@__FILE__), IOStream)  # Any other file works normally
    end

    @test_throws SystemError open("foo")
end

# TODO: Enable
# # Replacing isfile is tricky as it uses varargs.
# let
#     tmp_file = string(@__FILE__, ".null")  # Note: tempfile() on Windows creates a file
#     @test isfile(tmp_file) == false

#     mock_isfile = (p...) -> first(p) == tmp_file ? true : Original.isfile(p...)
#     mend(isfile, mock_isfile) do
#         @test isfile(tmp_file) == true
#     end

#     @test isfile(tmp_file) == false
# end


### Patch Interface ###

# Patch interface should allow the same behaviour of using mend directly
let
    # Ensure that open cannot find the file "foo"
    @test !isfile("foo")
    @test_throws SystemError open("foo")

    replacement = (name) -> name == "foo" ? IOBuffer("bar") : Original.open(name)

    # Ambiguious replacements should raise an exception
    patch = Patch(open, replacement)
    @test_throws ErrorException mend(patch) do
        nothing
    end

    @test_throws SystemError open("foo")

    # Replacement is no longer ambiguious if we supply a specific signature
    patch = Patch(open, replacement, (AbstractString,))
    mend(patch) do
        @test @mendable readstring(open("foo")) == "bar"
        @test @mendable isa(open(@__FILE__), IOStream)  # Any other file works normally
    end

    @test_throws SystemError open("foo")

    # Replacement is no longer ambiguious since we added a more specific signature
    replacement = (name::AbstractString) -> name == "foo" ? IOBuffer("bar") : Original.open(name)
    patch = Patch(open, replacement)
    mend(patch) do
        @test @mendable readstring(open("foo")) == "bar"
        @test @mendable isa(open(@__FILE__), IOStream)  # Any other file works normally
    end

    @test_throws SystemError open("foo")
end

# Pre-creating patches allows making the mend call easier to read
let
    internal(filename) = @mendable isfile(filename) && readstring(open(filename))

    # Testing with both generic and anonymous functions
    new_isfile(f::AbstractString) = f == "foo" ? true : Original.isfile(f)
    new_open = (f::AbstractString) -> f == "foo" ? IOBuffer("bar") : Original.open(f)

    patch_isfile = Patch(isfile, new_isfile)
    patch_open = Patch(open, new_open)

    mend(patch_isfile, patch_open) do
        @test internal("foo") == "bar"
    end
    mend([patch_isfile, patch_open]) do
        @test internal("foo") == "bar"
    end

    # Strange corner cases that will probably never happen in reality
    mend([patch_isfile]) do
        @test_throws SystemError internal("foo")
    end
    mend(Patch[]) do
        @test internal("foo") == false
    end
end
