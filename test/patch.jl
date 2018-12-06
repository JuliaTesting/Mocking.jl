import Dates: Hour




f(args...)= NaN # Must declare function before mocking it

@testset "patch" begin
    @testset "basic" begin
        p = @patch f(a, b::Int64, c=3, d::Integer=4; e=5, g::Int32=6) = nothing
        @test p.signature == :(Main.f(a, b::Core.Int64, c=3, d::Core.Integer=4; e=5, g::Core.Int32=6))
    end

    @testset "f as arg and function name" begin
        p = @patch f(f) = nothing
        @test_broken p.signature == :(Main.f(f))
    end

    @testset "variable argument parameters" begin
        p = @patch f(a::Integer...) = nothing
        @test p.signature == :(Main.f(a::Core.Integer...))
    end

    @testset "variable keyword parameters" begin
        p = @patch f(; a...) = nothing
        @test p.signature == :(Main.f(; a...))
    end

    # Issue #15
    @testset "anonymous parameter" begin
        function next_gensym(str::AbstractString, offset::Integer=1)
            m = match(r"^(.*?)(\d+)$", string(gensym(str)))
            return Symbol(string(m.captures[1], parse(Int, m.captures[2]) + offset))
        end


        anon = next_gensym("anon", 1)
        p = @patch f(::Type{UInt8}, b::Int64) = nothing
        @test p.signature == :(Main.f($anon::Core.Type{Core.UInt8}, b::Core.Int64))
    end

    @testset "assertion expression" begin
        p = @patch f(t::typeof(+)) = nothing
        @test p.signature == :(Main.f(t::typeof(Main.Base.:+)))
    end

    @testset "assertion qualification" begin
        patches = [
            @patch f(h::Base.Core.Int64=rand(Base.Core.Int64)) = nothing
            @patch f(h::Core.Int64=rand(Core.Int64)) = nothing
            @patch f(h::Int64=rand(Int64)) = nothing
        ]
        for p in patches
            @test p.signature == :(Main.f(h::Core.Int64=Main.Random.rand(Core.Int64)))
        end
    end



    @testset "array default" begin
        p = @patch f(a=[]) = a
        @test p.signature == :(Main.f(a=[]))
    end

    @testset "tuple default" begin
        p = @patch f(a=()) = a
        @test p.signature == :(Main.f(a=()))
    end
end
