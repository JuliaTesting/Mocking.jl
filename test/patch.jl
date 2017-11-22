import Dates
import Dates: Hour

@testset "patch" begin
    @testset "basic" begin
        p = @patch f(a, b::Int64, c=3, d::Integer=4; e=5, f::Int=6) = nothing
        @test p.signature == :(f(a, b::Core.Int64, c=3, d::Core.Integer=4; e=5, f::$INT_EXPR=6))
        @test p.modules == Set([:Core])
    end

    @testset "vararg parameter" begin
        p = @patch f(a::Integer...) = nothing
        @test p.signature == :(f(a::Core.Integer...))
        @test p.modules == Set([:Core])
    end

    # Issue #15
    @testset "anonymous parameter" begin
        anon = next_gensym("anon", 1)
        p = @patch f(::Type{UInt8}, b::Int64) = nothing
        @test p.signature == :(f($anon::Core.Type{Core.UInt8}, b::Core.Int64))
        @test p.modules == Set([:Core])
    end

    @testset "assertion expression" begin
        p = @patch f(t::typeof(cos)) = nothing
        @test p.signature == :(f(t::typeof(Base.MPFR.cos)))
        @test p.modules == Set([:(Base.MPFR)])
    end

    @testset "assertion qualification" begin
        patches = [
            @patch f(h::Base.Core.Int64=rand(Base.Core.Int64)) = nothing
            @patch f(h::Core.Int64=rand(Core.Int64)) = nothing
            @patch f(h::Int64=rand(Int64)) = nothing
        ]
        for p in patches
            @test p.signature == :(f(h::Core.Int64=Base.Random.rand(Core.Int64)))
            @test p.modules == Set([:Core, :(Base.Random)])
        end
    end
end
