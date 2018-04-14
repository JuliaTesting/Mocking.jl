import Compat: Dates
import Dates: Hour

@testset "joinbinding" begin
    @test Mocking.joinbinding(:Foo) == :(Foo)
    @test Mocking.joinbinding(:Foo, :Bar) == :(Foo.Bar)
    @test Mocking.joinbinding(:Foo, :Bar, :Baz) == :(Foo.Bar.Baz)
end

@testset "splitbinding" begin
    @test Mocking.splitbinding(:(Foo)) == [:Foo]
    @test Mocking.splitbinding(:(Foo.Bar)) == [:Foo, :Bar]
    @test Mocking.splitbinding(:(Foo.Bar.Baz)) == [:Foo, :Bar, :Baz]
end

@testset "binding_expr" begin
    @test Mocking.binding_expr(Int) == INT_EXPR  # typealias. TODO: Change to Core.Int? Shouldn't actually matter
    @test Mocking.binding_expr(Int64) == :(Core.Int64)  # concrete type
    @test Mocking.binding_expr(Integer) == :(Core.Integer)  # abstract type
    @test Mocking.binding_expr(Hour) == HOUR_EXPR  # unexported type
    @test Mocking.binding_expr(Dates.Hour) == HOUR_EXPR  # submodule
    @test Mocking.binding_expr(rand) == RAND_EXPR  # function
    @test Mocking.binding_expr(AbstractArray{Int64}) == :(Core.AbstractArray)  # Core.AbstractArray{Int64}?
    @test Mocking.binding_expr(Union{Int16,Int32,Int64}) == :(Union{Core.Int16,Core.Int32,Core.Int64})
    # @test Mocking.binding_expr(AbstractArray{T}) == :(Core.AbstractArray{T})
end

@testset "adjust_bindings" begin
    trans = Dict(:Int => Int, :Int64 => Int64, :Integer => Integer)
    @test Mocking.adjust_bindings(trans) == Dict(
        :Int => INT_EXPR,
        :Int64 => :(Core.Int64),
        :Integer => :(Core.Integer),
    )
end

@testset "call_parameters" begin
    expr = :(f(a, b::Int64, c=3, d::Integer=4; e=5, f::Int=6))
    @test Mocking.call_parameters(expr) == [Expr(:parameters, Expr(:kw, :e, :e), Expr(:kw, :f, :f)), :a, :b, :c, :d]

    expr = :(f(a..., b::Integer...))
    @test Mocking.call_parameters(expr) == Any[Expr(:..., :a), Expr(:..., :b)]

    expr = :(f(h::Hour=Hour(rand(1:24))))
    @test Mocking.call_parameters(expr) == Any[:h]

    expr = :(f(a::AbstractArray{Int64}))
    @test Mocking.call_parameters(expr) == Any[:a]

    expr = :(f{T}(a::AbstractArray{T}))
    @test Mocking.call_parameters(expr) == Any[:a]
end
