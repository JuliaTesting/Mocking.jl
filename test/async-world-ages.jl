using Test
using Mocking

# Issue #108
# TODO: Test is mostly redundant with "async-scope.jl". We may want to update those tests to
# also validate we can run in a later world age.
@testset "patching an async task from an earlier world age" begin
    function foo(x)
        @mock bar(x)
    end

    bar(x) = x

    # Before the patch
    @test bar(2) == 2

    # NOTE: Every top-level statement in a testset is run in a new world age.
    if VERSION >= v"1.5"
        intial_world_age = Base.get_world_counter()
    end

    # Start a background async task. For Julia 1.11+ this task will consistently use the
    # patch environment which it was started in. In earlier versions of Julia we can patch
    # this task while it's running can call functions defined in a later world age than the
    # world age of this task.
    ch = Channel() do ch
        # Block until we've started the patch
        v1 = take!(ch)
        # Call the (patched) foo
        v2 = foo(v1)
        # return the value
        put!(ch, v2)
    end

    # Make sure we're actually testing what we think we are.
    if VERSION >= v"1.5"
        @assert Base.get_world_counter() > intial_world_age
    end

    p = @patch bar(x) = 10 * x

    apply(p) do
        # Release the background task
        put!(ch, 2)
        # Fetch the task's result

        # https://github.com/JuliaLang/julia/pull/50958
        if VERSION >= v"1.11.0-DEV.482"
            @test take!(ch) == 2
        else
            @test_broken take!(ch) == 2
        end
    end
end
