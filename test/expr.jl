import Base.Dates: Hour
import Compat: @static

@test Mocking.joinbinding(:Foo) == :(Foo)
@test Mocking.joinbinding(:Foo, :Bar) == :(Foo.Bar)
@test Mocking.joinbinding(:Foo, :Bar, :Baz) == :(Foo.Bar.Baz)

@test Mocking.splitbinding(:(Foo)) == [:Foo]
@test Mocking.splitbinding(:(Foo.Bar)) == [:Foo, :Bar]
@test Mocking.splitbinding(:(Foo.Bar.Baz)) == [:Foo, :Bar, :Baz]

int_expr = Int === Int32 ? :(Core.Int32) : :(Core.Int64)
@test Mocking.binding_expr(Int) == int_expr  # typealias. TODO: Change to Core.Int? Shouldn't actually matter
@test Mocking.binding_expr(Int64) == :(Core.Int64)  # concrete type
@test Mocking.binding_expr(Integer) == :(Core.Integer)  # abstract type
@test Mocking.binding_expr(Hour) == :(Base.Dates.Hour)  # unexported type
@test Mocking.binding_expr(Dates.Hour) == :(Base.Dates.Hour)  # submodule
@test Mocking.binding_expr(Base.Dates.Hour) == :(Base.Dates.Hour)  # full type binding
@test Mocking.binding_expr(rand) == :(Base.Random.rand)  # function
@test Mocking.binding_expr(AbstractArray{Int64}) == :(Core.AbstractArray)  # Core.AbstractArray{Int64}?
# @test Mocking.binding_expr(AbstractArray{T}) == :(Core.AbstractArray{T})

trans = Dict(:Int => Int, :Int64 => Int64, :Integer => Integer)
@test Mocking.adjust_bindings(trans) == Dict(
    :Int => int_expr,
    :Int64 => :(Core.Int64),
    :Integer => :(Core.Integer),
)


expr = :(f(a, b::Int64, c=3, d::Integer=4; e=5, f::Int=6))
# @test Mocking.extract_bindings(expr.args[2:end]) == Set([:Int64, :Integer, :Int])
@test Mocking.call_parameters(expr) == [Expr(:parameters, Expr(:kw, :e, :e), Expr(:kw, :f, :f)), :a, :b, :c, :d]

expr = :(f(a..., b::Integer...))
# @test Mocking.extract_bindings(expr.args[2:end]) == Set([:Integer])
@test Mocking.call_parameters(expr) == Any[Expr(:..., :a), Expr(:..., :b)]

expr = :(f(h::Hour=Hour(rand(1:24))))
# @test Mocking.extract_bindings(expr.args[2:end]) == Set([:Hour, :rand])
@test Mocking.call_parameters(expr) == Any[:h]

expr = :(f(a::AbstractArray{Int64}))
# @test Mocking.extract_bindings(expr.args[2:end]) == Set([:(AbstractArray{Int64})])
@test Mocking.call_parameters(expr) == Any[:a]

expr = :(f{T}(a::AbstractArray{T}))
# @test Mocking.extract_bindings(expr.args[2:end]) == Set([:(AbstractArray{T})])
@test Mocking.call_parameters(expr) == Any[:a]
