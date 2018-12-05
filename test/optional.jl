using Mocking
using Test
using Dates
using Dates: Hour

# Creating a patch with an optional parameter
hourvalue(h::Hour=Hour(0)) = Dates.value(h)
@testset "patch with optional parameter" begin

    @testset "Patch sensibility check" begin
        # There is some subtleness with the imports here,
        # So we want to be sure our code is actually going to run in current
        # namespace before we throw it to cassette

        # The code for `preview_hourvalue` should match the patch
        preview_hourvalue(h::Hour=Hour(21)) = 2 * Dates.value(h)
        @test preview_hourvalue(Hour(4)) == 8
        @test preview_hourvalue() == 42
    end


    patch = @patch hourvalue(h::Hour=Hour(21)) = 2 * Dates.value(h)
    apply(patch) do
        @test hourvalue(Hour(4)) == 8
        @test hourvalue() == 42
    end
end

#=

# Creating a patch with an keyword parameter
hourvalue_kw(; hour::Hour=Hour(0)) = Dates.value(hour)
@testset "patch with keyword parameter" begin

    patch = @patch hourvalue_kw(; hour::Hour=Hour(21)) = 2 * Dates.value(hour)
    apply(patch) do
        @test hourvalue_kw() == 42

        # Test @mock calls with keyword arguments
        @test hourvalue_kw(hour=Hour(4)) == 8      #:kw
        @test hourvalue_kw(; hour=Hour(4)) == 8    #:parameters
    end
end
=#
