using Logging

@testset "logging" begin
    activated_before_tests = Mocking.activated()

    buf = IOBuffer()
    logger = ConsoleLogger(IOContext(buf), Logging.Debug)

    # Note: ending the `with_logger` do block right after `activate()` because `activate()`
    # uses @eval under the hood, and so Mocking will only be `activated()` once out of the
    # function scope (created by the do block syntax).
    # Same for `deactivate()` further down.
    with_logger(logger) do
        Mocking.activate()
        @test occursin("Calling Mocking.activate()", String(take!(buf)))
    end

    f() = 1
    f(x) = 1

    p1 = @patch f() = 2
    
    with_logger(logger) do
        Mocking.apply(p1) do
            @test occursin("Applying patch", String(take!(buf)))

            @mock f()
            log = String(take!(buf))
            @test occursin("Mocking activated, @mock macro expanding to `get_alternate` for target", log)
            @test occursin("Triggering patch", log)

            @mock f(1)
            @test occursin("Not triggering any patch", String(take!(buf)))
        end
    end

    with_logger(logger) do
        Mocking.deactivate()
        @test occursin("Calling Mocking.deactivate()", String(take!(buf)))
    end

    with_logger(logger) do
        Mocking.apply(p1) do
            @test occursin("Applying patch", String(take!(buf)))

            @mock f()
            @test occursin("Mocking not activated, @mock macro expanding to the original target", String(take!(buf)))
        end
    end

    if activated_before_tests
        Mocking.activate()
    end
end
