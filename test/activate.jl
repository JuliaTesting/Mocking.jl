@testset "activate(func)" begin
    add1(x) = x + 1
    patch = @patch add1(x) = x + 42

    # Starting with Mocking enabled.
    Mocking.activate()
    @assert Mocking.activated()
    Mocking.activate() do
        apply(patch) do
            @test (@mock add1(2)) == 44
        end
    end
    @test Mocking.activated()

    # Starting with Mocking disabled.
    # Make sure to leave it enabled for the rest of the tests.
    try
        Mocking.deactivate()
        @assert !Mocking.activated()
        Mocking.activate() do
            apply(patch) do
                @test (@mock add1(2)) == 44
            end
        end
        @test !Mocking.activated()
    finally
        Mocking.activate()
    end
end
