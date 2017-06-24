import Base: Dates
import Base.Dates: Hour

int_expr = Int === Int32 ? :(Core.Int32) : :(Core.Int64)
p = @patch f(a, b::Int64, c=3, d::Integer=4; e=5, f::Int=6) = nothing
@test p.signature == :(f(a, b::Core.Int64, c=3, d::Core.Integer=4; e=5, f::$int_expr=6))
@test p.modules == Set([:Core])

p = @patch f(a::Integer...) = nothing
@test p.signature == :(f(a::Core.Integer...))
@test p.modules == Set([:Core])

# Issue #15
anon = next_gensym("anon", 2)
p = @patch f(::Type{UInt8}, b::Int64) = nothing
@test p.signature == :(f($anon::Core.Type{Core.UInt8}, b::Core.Int64))
@test p.modules == Set([:Core])

p = @patch f(t::typeof(cos)) = nothing
if VERSION < v"0.5-"
    @test p.signature == :(f(t::typeof(Base.cos)))
    @test p.modules == Set([:Base])
else
    @test p.signature == :(f(t::typeof(Base.MPFR.cos)))
    @test p.modules == Set([:(Base.MPFR)])
end

patches = [
    @patch f(h::Base.Dates.Hour=Base.Dates.Hour(rand())) = nothing
    @patch f(h::Dates.Hour=Dates.Hour(rand())) = nothing
    @patch f(h::Hour=Hour(rand())) = nothing
]
for p in patches
    @test p.signature == :(f(h::Base.Dates.Hour=Base.Dates.Hour(Base.Random.rand())))
    @test p.modules == Set([:(Base.Dates), :(Base.Random)])
end
