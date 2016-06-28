import Base.Dates: Hour

f = :(foo(h::Hour=Hour(0)) = 0)
r = :(foo(h::Base.Dates.Hour=Base.Dates.Hour(0)) = 0)
params = f.args[1].args[2:end]
expected = r.args[1].args[2:end]

@test params != expected
@test Mocking.qualify!(params) == Union{Expr,Symbol}[:(Base.Dates), :(Base.Dates)]
@test params == expected

@test Mocking.joinbinding(:Foo) == :(Foo)
@test Mocking.joinbinding(:Foo, :Bar) == :(Foo.Bar)
@test Mocking.joinbinding(:Foo, :Bar, :Baz) == :(Foo.Bar.Baz)

@test Mocking.splitbinding(:(Foo)) == Symbol[:Foo]
@test Mocking.splitbinding(:(Foo.Bar)) == Symbol[:Foo, :Bar]
@test Mocking.splitbinding(:(Foo.Bar.Baz)) == Symbol[:Foo, :Bar, :Baz]
