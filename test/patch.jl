import Base: Dates
import Base.Dates: Hour

p = @patch f(a, b::Int64, c=3, d::Integer=4; e=5, f::Int=6) = nothing
@test p.signature == :(f(a, b::Core.Int64, c=3, d::Core.Integer=4; e=5, f::Core.Int64=6))
@test p.modules == Set([:Core])

p = @patch f(a::Integer...) = nothing
@test p.signature == :(f(a::Core.Integer...))
@test p.modules == Set([:Core])

patches = [
    @patch f(h::Base.Dates.Hour=Base.Dates.Hour(rand())) = nothing
    @patch f(h::Dates.Hour=Dates.Hour(rand())) = nothing
    @patch f(h::Hour=Hour(rand())) = nothing
]
for p in patches
    @test p.signature == :(f(h::Base.Dates.Hour=Base.Dates.Hour(Base.Random.rand())))
    @test p.modules == Set([:(Base.Dates), :(Base.Random)])
end
