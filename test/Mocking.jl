import Mocking: override, mend, Signature
using Base.Test

# Test the concept of overwriting methods in Julia
let generic() = "foo"
    @test generic() == "foo"
    generic() = "bar"
    @test generic() == "bar"
end

# generic functions that only exist within a let block currently cannot be overwritten (yet)
let generic() = "foo"
    @test generic() == "foo"
    @test_throws UndefVarError Main.generic()

    @test_throws MethodError override(generic, () -> "bar") do
        nothing  # Note: Never executed
    end

    @test generic() == "foo"
    @test_throws UndefVarError Main.generic()
end

# Non-generic functions can be overridden no matter where they are defined
let anonymous = () -> "foo"
    @test anonymous() == "foo"
    override(anonymous, () -> "bar") do
        @test anonymous() == "bar"
    end
    @test anonymous() == "foo"
end

# Generic functions can be overwritten if they are defined globally within the module
let open = Base.open
    @test_throws SystemError open("foo")

    # Ambiguious replacements should raise an exception
    replacement = (name) -> name == "foo" ? IOBuffer("bar") : Original.open(name)
    @test_throws UndefVarError Original.open
    @test_throws ErrorException mend(() -> nothing, open, replacement)
    @test isa(Original.open, Function)  # TODO: Original methods should be cleared after mend

    @test_throws SystemError open("foo")

    # Replacement is no longer ambiguious if we supply a specific signature
    mend(open, replacement, (AbstractString,)) do
        @test readall(open("foo")) == "bar"
        @test isa(open(@__FILE__), IOStream)  # Any other file works normally
    end

    @test_throws SystemError open("foo")

    # Replacement is no longer ambiguious since we added a more specific signature
    replacement = (name::AbstractString) -> name == "foo" ? IOBuffer("bar") : Original.open(name)
    mend(open, replacement) do
        @test readall(open("foo")) == "bar"
        @test isa(open(@__FILE__), IOStream)  # Any other file works normally
    end

    @test_throws SystemError open("foo")
end

# Let blocks seem more forgiving. Ensure that mend works outside of a let block
@test !isfile("foobar.txt")
@test_throws SystemError open("foobar.txt")

mock_open = (name::AbstractString) -> name == "foobar.txt" ? IOBuffer("Hello Julia") : Original.open(name)

mend(open, mock_open) do
    @test readall(open("foobar.txt")) == "Hello Julia"
    @test isa(open(@__FILE__), IOStream)
end

@test_throws SystemError open("foobar.txt")

# Ensure that compiled functions that use methods that will be mended are modified
let
    # Example of why @mendable is needed:
    invalid() = readall(open("foo"))
    @test_throws SystemError invalid()

    replacement(name::AbstractString) = IOBuffer("bar")
    mend(open, replacement) do
        @test_throws SystemError invalid()  # Mend fails as open will be embedded
    end

    @test_throws SystemError invalid()

    # The @mendable macro in use:
    valid() = @mendable readall(open("foo"))  # Force open not to be inlined here
    @test_throws SystemError valid()

    replacement(name::AbstractString) = IOBuffer("bar")
    mend(open, replacement) do
        @test valid() == "bar"
    end

    @test_throws SystemError valid()
end

# Replacing isfile is tricky as it uses varargs.
tmp_file = string(@__FILE__, ".null")  # Note: tempfile() on Windows creates a file
@test isfile(tmp_file) == false

mock_isfile = (f::AbstractString) -> f == tmp_file ? true : Original.isfile(f)
mend(isfile, mock_isfile) do
    @test isfile(tmp_file) == true
end

@test isfile(tmp_file) == false


### User assistive error messages ###

# Attempt to override a generic function with no methods
let generic, empty_body = () -> nothing
    function generic end
    replacement() = true
    @test_throws ErrorException mend(empty_body, generic, replacement)
    @test_throws ErrorException override(empty_body, generic, replacement)
end

# Attempt to override a generic function with a generic function containing no methods
let generic, empty_body = () -> nothing
    generic() = true
    function replacement end
    @test_throws ErrorException override(empty_body, generic, replacement)
    @test_throws ErrorException mend(empty_body, generic, replacement)
    @test_throws ErrorException Patch(generic, replacement)
    @test_throws ErrorException Patch(generic, replacement, [Any])
end

# Attempt to override a ambiguious generic function
let generic, empty_body = () -> nothing
    generic(value::AbstractString) = value
    generic(value::Integer) = -value
    replacement(value) = true
    @test_throws ErrorException override(empty_body, generic, replacement)
end

# Attempt to override an non-ambiguious generic function with an ambiguious generic function
let generic, empty_body = () -> nothing
    generic(value) = value
    replacement(value::AbstractString) = "foo"
    replacement(value::Integer) = 0
    @test_throws ErrorException mend(empty_body, generic, replacement)
    @test_throws ErrorException override(empty_body, generic, replacement)
    @test_throws ErrorException Patch(generic, replacement)
    @test_throws ErrorException Patch(generic, replacement, [Any])
end
