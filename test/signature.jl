import Mocking: Signature, parameters

# Only can work on non-generic functions
# let generic() = nothing, generic(a::Int64) = nothing
#     @test_throws ArgumentError parameters(generic)
#     @test_throws ArgumentError Signature(generic)
# end

let f
    f = () -> nothing
    @test parameters(f) == (Symbol[], Type[])
    @test Signature(f) == Signature([])
    @test convert(Tuple, Signature(f)) == Tuple{}

    f = (a) -> nothing
    @test parameters(f) == ([:a], [Any])
    @test Signature(f) == Signature([Any])
    @test convert(Tuple, Signature(f)) == Tuple{Any}

    f = (a::Int64) -> nothing
    @test parameters(f) == ([:a], [Int64])
    @test Signature(f) == Signature([Int64])
    @test convert(Tuple, Signature(f)) == Tuple{Int64}

    f = (a, b::AbstractString) -> nothing
    @test parameters(f) == ([:a, :b], [Any, AbstractString])
    @test Signature(f) == Signature([Any, AbstractString])
    @test convert(Tuple, Signature(f)) == Tuple{Any,AbstractString}

    f = (a...) -> nothing
    @test parameters(f) == ([:a], [Vararg{Any}])
    @test Signature(f) == Signature([Vararg{Any}])
    @test convert(Tuple, Signature(f)) == Tuple  # Note: Tuple == Tuple{Vararg{Any}}

    f = (a, b...) -> nothing
    @test parameters(f) == ([:a, :b], [Any, Vararg{Any}])
    @test Signature(f) == Signature([Any, Vararg{Any}])
    @test convert(Tuple, Signature(f)) == Tuple{Any,Vararg{Any}}
end

# New "methods" method allows us to isolate a vararg method
let m
    m() = "empty"
    m(arg) = "arg"
    m(args...) = "vararg"

    @test length(methods(m, Tuple{Vararg{Any}})) == 3

    results = methods(m, Signature([Vararg{Any}]))
    @test length(results) == 1

    # TODO: Would be best to confirm we have the right method by calling it
    # @test first(results).func() == "vararg"
end

# Since we check for signature equality we could run into issues
# with selecting methods via a subtype
let m
    m(a::Number) = Number
    m(a::Integer) = Integer

    @test length(methods(m, Tuple{Int64})) == 1

    results = methods(m, Signature([Int64]))
    @test length(results) == 1

    # TODO: Would be best to confirm we have the right method by calling it
    # @test first(results).func(0) == Integer
end

# In certain cases you cannot retrieve the types from the compressed function. Seems
# to have only being a problem in Julia 0.4
method = first(methods(open, Tuple{AbstractString}))
@test parameters(method)[2] == [AbstractString]
@test Signature(method) == Signature([AbstractString])
