import Base.Dates: Hour

if VERSION < v"0.5-"
    # Mocking uses makes of anonymous functions for patches. Mocking cannot support optional
    # or keyword parameters while these are unsupported with anonymous functions.

    # Optional parameters are not allowed in anonymous functions
    expr = :((x::Integer=0) -> x)
    @test_throws ErrorException Core.eval(expr)

    # Keyword parameters are not allowed in anonymous functions
    expr = :((x; debug::Bool=false) -> debug)
    @test_throws ErrorException Core.eval(expr)


    # Creating a patch with an optional parameter is not supported
    let
        hourvalue(h::Hour=Hour(0)) = Base.Dates.value(h)

        @test_throws ErrorException eval(
            quote
                @patch hourvalue(h::Hour=Hour(0)) = 42
            end
        )

        patch = @patch hourvalue(h::Hour) = 42
        apply(patch) do
            @test (@mock hourvalue(Hour(5))) == 42
        end
    end

    # Creating a patch with an keyword parameter is not supported
    let
        hourvalue(; hour::Hour=Hour(0)) = Base.Dates.value(hour)

        @test_throws ErrorException eval(
            quote
                @patch hourvalue(; hour::Hour=Hour(0)) = 42
            end
        )

        patch = @patch hourvalue() = 42
        apply(patch) do
            @test (@mock hourvalue()) == 42
        end
    end
else
    # Creating a patch with an optional parameter is not supported
    let
        hourvalue(h::Hour=Hour(0)) = Base.Dates.value(h)

        # Note: Needs to be within an eval so that macro expansion on 0.4 doesn't occur
        patch = @eval begin
            @patch hourvalue(h::Hour=Hour(21)) = 2 * Base.Dates.value(h)
        end
        apply(patch) do
            @test (@mock hourvalue()) == 42
            @test (@mock hourvalue(Hour(4))) == 8
        end
    end

    # Creating a patch with an keyword parameter is not supported
    let
        hourvalue(; hour::Hour=Hour(0)) = Base.Dates.value(hour)

        # Note: Needs to be within an eval so that macro expansion on 0.4 doesn't occur
        patch = @eval begin
            @patch hourvalue(; hour::Hour=Hour(21)) = 2 * Base.Dates.value(hour)
        end
        apply(patch) do
            @test (@mock hourvalue()) == 42
            # @test (@mock hourvalue(hour=Hour(4))) == 8  # TODO
        end
    end
end

