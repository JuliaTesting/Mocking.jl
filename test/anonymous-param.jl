# Issue #15
f(::Type{T}, n::Int) where T<:Unsigned = rand(T, n)

@testset "anonymous parameter" begin

    patch = @patch f(::Type{UInt8}, n::Int) = collect(UnitRange{UInt8}(1:n))

    apply(patch) do
        @test f(UInt8, 2) == [0x01, 0x02]
    end
end
