using Mocking
import Mocking: module_and_name, FunctionError

# Test the concept of overriding methods in Julia
let generic() = "foo"
    @test generic() == "foo"
    Mocking.ignore_stderr() do
        generic() = "bar"
    end
    @test generic() == "bar"
end

# generic functions that only exist within a let block currently cannot be overwritten (yet)
# Note: this restriction comes from the usage of `eval` in `override`.
let generic() = "foo"
    # Method is indicated to exist in the module: Main
    @test length(methods(generic)) == 1
    @test module_and_name(first(methods(generic))) == (Main, :generic)

    # Function is inaccessable from module Main
    @test_throws UndefVarError Main.generic()
    @test generic() == "foo"

    # If we can overwrite generic functions create in a let then the test would look like:
    # override(generic, () -> "bar") do
    #     @test @mendable generic() == "bar"
    # end

    # Mocking needs to determine that it cannot override the given function
    @test_throws FunctionError Mocking.override(generic, () -> "bar") do
        nothing  # Note: Never should be executed
    end

    # Make sure things haven't been modified permanently
    @test_throws UndefVarError Main.generic()
    @test generic() == "foo"
end

# Non-generic functions can be overridden no matter where they are defined
let anonymous = () -> "foo"
    @test anonymous() == "foo"

    # Note: As of Julia 0.5- all functions are generic
    @test_throws FunctionError Mocking.override(anonymous, () -> "bar") do
        nothing  # Note: Never should be executed
    end

    @test anonymous() == "foo"
end

# Generic functions can be overridden temporarily in a let if they are defined globally
# within a module. Unfortunately there are issues with this...
temp() = nothing
temp(v) = nothing
let t = temp
    @test methods(t) == methods(temp)

    # As of Julia 0.5 attempting to add new method or override one will restrict the method
    # table to only contain functions defined within the scope of the let
    t(s::AbstractString) = s
    @test length(methods(t)) == 1
    @test length(methods(temp)) == 2
end

# Using a let block and using the globally defined function directly acts in the way we want
let
    @test length(methods(temp)) == 2
    temp(s::UTF8String) = s
    @test length(methods(temp)) == 3
end

# The downside is that the function will be permanently modified for the duration of the
# Julia session
@test length(methods(temp)) == 3


# Basic use case for the need for @mendable
inner() = "foo"
let fixed, dynamic
    fixed() = inner()
    dynamic() = @mendable inner()

    @test fixed() == "foo"
    @test dynamic() == "foo"

    # Override "inner" and hide the method overwritten message.
    # Note: Somehow using ignore_stderr stops this test from working
    @unix_only stderr = Base.STDERR
    @unix_only redirect_stderr(open("/dev/null", "w"))
    inner() = "bar"
    @unix_only redirect_stderr(stderr)

    @test fixed() == "foo"    # Mend fails as call is embedded
    @test dynamic() == "bar"  # Mend successful
end

# Basic use case for override
inner_override() = "foo"
let fixed, dynamic
    fixed() = inner_override()
    dynamic() = @mendable inner_override()

    @test fixed() == "foo"
    @test dynamic() == "foo"

    replacement = () -> "bar"
    Mocking.override(inner_override, replacement) do
        @test fixed() == "foo"    # Mend fails as open will be embedded
        @test dynamic() == "bar"  # Mend successful
    end

    @test fixed() == "foo"
    @test dynamic() == "foo"
end


### User assistive error messages ###

body = () -> nothing

# The following functions need to be declared at the global module in order to allow
# the possibility of overriding.
function empty_generic end
single_generic() = true

specific(value::AbstractString) = endof(value)
specific(value::Integer) = -value
general(value) = value

# Ensure that the generic functions we have created have precisely the amount of methods we
# have just declared. Otherwise things could potentially not raise and exception.
@test length(methods(empty_generic)) == 0
@test length(methods(single_generic)) == 1
@test length(methods(specific)) == 2
@test length(methods(general)) == 1

# Attempt to override an empty generic function with no methods
@test_throws ErrorException Mocking.override(body, empty_generic, single_generic)
@test_throws ErrorException Mocking.mend(body, empty_generic, single_generic)

# Attempt to override a generic function with a generic function containing no methods
@test_throws ErrorException Mocking.override(body, single_generic, empty_generic)
@test_throws ErrorException Mocking.mend(body, single_generic, empty_generic)
@test_throws ErrorException Mocking.Patch(single_generic, empty_generic)
@test_throws ErrorException Mocking.Patch(single_generic, empty_generic, [Any])

# Attempt to override a ambiguious generic function
@test_throws ErrorException Mocking.override(body, specific, general)

# Attempt to override an non-ambiguious generic function with an ambiguious generic function
@test_throws ErrorException Mocking.override(body, general, specific)
@test_throws ErrorException Mocking.mend(body, general, specific)
@test_throws ErrorException Mocking.Patch(general, specific)
@test_throws ErrorException Mocking.Patch(general, specific, [Any])
