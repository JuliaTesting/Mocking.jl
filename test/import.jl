import Compat: readstring

# Patches should allow using imported bindings in the body of the patch
@test_throws UndefVarError Minute
@test isdefined(Base.Dates, :Minute)
import Base.Dates: Minute, Hour

let
    myminute(x::Integer) = Minute(x)

    # Patches should work when referencing bindings imported in the file where the patch
    # is created.
    patch = @patch myminute(x::Integer) = Minute(Hour(x))
    apply(patch) do
        @test (@mock myminute(5)) == Minute(300)
    end
end

# Patches should allow using <module>.<binding> syntax in the signature
@test_throws UndefVarError AbstractCmd
@test isdefined(Base, :AbstractCmd)

patch = @patch readstring(cmd::Base.AbstractCmd) = "bar"
apply(patch) do
    @test (@mock readstring(`foo`)) == "bar"
end
