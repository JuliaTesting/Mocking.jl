# Issue #15
@testset "anonymous parameter" begin
    f(::Type{T}, n::Int) where T<:Unsigned = rand(T, n)

    patch = @patch f(::Type{UInt8}, n::Int) = collect(UnitRange{UInt8}(1:n))

    apply(patch) do
        @test (@mock f(UInt8, 2)) == [0x01, 0x02]
    end
end
