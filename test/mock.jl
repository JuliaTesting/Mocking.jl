@testset "mock keyword" begin
    f(; x=1) = x

    function f_param()
        x = 2
        return @mock f(; x=x)
    end

    @test f_param() == 2

    function f_kw()
        x = 3
        return @mock f(x=x)
    end

    @test f_kw() == 3

    @static if VERSION >= v"1.5"
        function f_req_param()
            x = 4
            return @mock f(; x)  # Testing keyword parameter that is just a `Symbol`
        end

        @test f_req_param() == 4
    end
end
