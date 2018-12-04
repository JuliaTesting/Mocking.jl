# https://github.com/invenia/Mocking.jl/issues/14

statuscode(url::AbstractString) = 500

@testset "patch generation" begin

    function foo(status::Int)
        statuscode("http://httpbin.org/status/$status")
    end

    # Previously Mocking would modify the function expression in place. Reusing this
    # modified expression would cause the absolute_binding translation to fail upon
    # generating a second patch.
    patch(status) = @patch statuscode(url::AbstractString) = status

    apply(patch(200)) do
        @test foo(200) == 200
    end

    # Calling `patch` a second time would generate an exception
    apply(patch(404)) do
        @test foo(404) == 404
    end
end
