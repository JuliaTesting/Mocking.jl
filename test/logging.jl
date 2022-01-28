using Memento.TestUtils

@testset "logging" begin

    Memento.config!("trace"; recursive=true)
    setlevel!(getlogger("Mocking"), "trace"; recursive=true) # TODO set back to default after tests run (even if errors get thrown)

    Mocking.activate()

    f() = 1
    f(x) = 1
    f(x, y) = 1
    f(x, y, z) = 1

    function f_param()
        return @mock f(1, 2, 3)
    end

    p1 = @patch f(x) = 2
    p2 = @patch f(x, y) = 2
    Mocking.apply([p1, p2]) do
        @show f_param()
    end

    # @test_log(
    #     Mocking.LOGGER,
    #     "trace",
    #     "Mocking activated, @mock macro expanding to `get_alternate` for target: f",
    #     f_param(),
    # )

    # Mocking.deactivate() # TODO set back to default after tests run (even if errors get thrown)

    # f_param()


    # @test_log(
    #     Mocking.LOGGER,
    #     "trace",
    #     "Mocking not activated, @mock macro expanding to the original target: f",
    #     f_param(),
    # )


end
