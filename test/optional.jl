import Compat: Dates
import .Dates: Hour

# Creating a patch with an optional parameter
@testset "patch with optional parameter" begin
    hourvalue(h::Hour=Hour(0)) = Dates.value(h)

    patch = @patch hourvalue(h::Hour=Hour(21)) = 2 * Dates.value(h)
    apply(patch) do
        @test (@mock hourvalue()) == 42
        @test (@mock hourvalue(Hour(4))) == 8
    end
end

# Creating a patch with an keyword parameter
@testset "patch with keyword parameter" begin
    hourvalue(; hour::Hour=Hour(0)) = Dates.value(hour)

    patch = @patch hourvalue(; hour::Hour=Hour(21)) = 2 * Dates.value(hour)
    apply(patch) do
        @test (@mock hourvalue()) == 42

        # Test @mock calls with keyword arguments
        @test (@mock hourvalue(hour=Hour(4))) == 8      #:kw
        @test (@mock hourvalue(; hour=Hour(4))) == 8    #:parameters
    end
end
