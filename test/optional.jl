import Base.Dates: Hour

# Creating a patch with an optional parameter
let
    hourvalue(h::Hour=Hour(0)) = Base.Dates.value(h)

    patch = @patch hourvalue(h::Hour=Hour(21)) = 2 * Base.Dates.value(h)
    apply(patch) do
        @test (@mock hourvalue()) == 42
        @test (@mock hourvalue(Hour(4))) == 8
    end
end

# Creating a patch with an keyword parameter
let
    hourvalue(; hour::Hour=Hour(0)) = Base.Dates.value(hour)

    patch = @patch hourvalue(; hour::Hour=Hour(21)) = 2 * Base.Dates.value(hour)
    apply(patch) do
        @test (@mock hourvalue()) == 42
        # @test (@mock hourvalue(hour=Hour(4))) == 8  # TODO
    end
end
