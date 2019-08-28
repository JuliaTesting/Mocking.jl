# Make sure that arguments are only evaluated once
@testset "one-time argument evaluation" begin
    function counter()
        i = 0
        count() = i += 1
        return count
    end

    p = @patch string(x) = "$x"

    # Check code path where we execute a patch
    c = counter()
    apply(p) do
        @test (@mock string(c())) == "1"
    end

    # Check code path where we fallback to the original function
    c = counter()
    apply(Patch[]) do
        @test (@mock string(c())) == "1"
    end
end
