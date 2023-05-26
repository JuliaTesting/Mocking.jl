using Test
using Mocking

# Issue #108
@testset "patching an async task from an earlier world age" begin
    function foo(x)
        @mock bar(x)
    end

    bar(x) = x

    # Before the patch
    @test bar(2) == 2

    # NOTE: Every top-level statement in a testset is run in a new world age.
    intial_world_age = Base.get_world_counter()

    # Start a background, async task which blocks until bar() is patched, so that we
    # can test that patches to functions defined in later world ages can be called
    # from mocks in a Task running in an earlier world age.
    ch = Channel() do ch
        # Block until we've started the patch
        v1 = take!(ch)
        # Call the (patched) foo
        v2 = foo(v1)
        # return the value
        put!(ch, v2)
    end

    # Make sure we're actually testing what we think we are.
    @assert Base.get_world_counter() > intial_world_age

    p = @patch bar(x) = 10 * x

    apply(p) do
        # Release the background task
        put!(ch, 2)
        # Fetch the task's result
        @test take!(ch) == 20
    end
end
