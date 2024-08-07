# Async tasks should consistently use the patch environment (if any) they started with.
@testset "async scope" begin
    c = Condition()
    ch = Channel{String}(1)
    f() = "original"
    function background()
        # Wait until notified allowing us to control when this async code is executed
        wait(c)
        put!(ch, @mock f())
        return nothing
    end

    p = @patch f() = "mocked"

    @sync begin
        # Task started outside patched context should not call patched functions.
        @async background()
        yield()

        apply(p) do
            @test (@mock f()) == "mocked"

            notify(c)
            # https://github.com/JuliaLang/julia/pull/50958
            if VERSION >= v"1.11.0-DEV.482"
                @test take!(ch) == "original"
            else
                @test_broken take!(ch) == "original"
            end

            # Task started inside patched context should call patched functions.
            @async background()
            yield()
            notify(c)
            @test take!(ch) == "mocked"

            # Task started inside patched context should call patched functions even when
            # execution finishes outside of patched context.
            @async background()
            yield()
        end

        notify(c)
        # https://github.com/JuliaLang/julia/pull/50958
        if VERSION >= v"1.11.0-DEV.482"
            @test take!(ch) == "mocked"
        else
            @test_broken take!(ch) == "mocked"
        end
    end
end
