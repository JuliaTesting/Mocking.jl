using Patch
using Base.Test

# Test the concept of overwritten methods in Julia
let generic() = "foo"
    @test generic() == "foo"
    generic() = "bar"
    @test generic() == "bar"
end

# generic functions that only exist within a let block currently cannot be overwritten (yet)
let generic() = "foo"
    @test generic() == "foo"
    @test_throws UndefVarError Main.generic()

    @test_throws MethodError Patch.override(generic, () -> "bar") do
        @test generic() == "bar"  # Note: Never executed
    end

    @test generic() == "foo"
    @test_throws UndefVarError Main.generic()
end

# Non-generic functions can be overridden no matter where they are defined
let anonymous = () -> "foo"
    @test anonymous() == "foo"
    Patch.override(anonymous, () -> "bar") do
        @test anonymous() == "bar"
    end
    @test anonymous() == "foo"
end

# Generic functions can be overwritten if they are defined globally within the module
let open = Base.open
    @test_throws SystemError open("foo")

    replacement = (name) -> name == "foo" ? "bar" : Original.open(name)
    @test_throws ErrorException Patch.patch(open, replacement) do nothing end

    @test_throws SystemError open("foo")

    replacement = (name::AbstractString) -> name == "foo" ? "bar" : Original.open(name)
    Patch.patch(open, replacement) do
        @test open("foo") == "bar"
        @test isa(open(tempdir()), IOStream)
    end

    @test_throws SystemError open("foo")
end
