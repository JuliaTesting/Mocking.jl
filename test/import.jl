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
