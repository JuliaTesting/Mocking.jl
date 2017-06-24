import Mocking: Bindings, ingest_parametric!

# Note: The `f{A}` parametric syntax and `where` are equal when looking at individual
# components.

@test @valid_method f{A}(::Type{A}) = A
b = Bindings()
ingest_parametric!(b, :A)
@test b.internal == Set([:A])
@test b.external == Set([])

if VERSION >= v"0.6"
    @test @valid_method f{A,B<:A}(::Type{A}, ::Type{B}) = A, B
end
ingest_parametric!(b, :(B<:A))
@test b.internal == Set([:A, :B])
@test b.external == Set([])

@test @valid_method f{A<:Integer}(::Type{A}) = A
b = Bindings()
ingest_parametric!(b, :(A<:Integer))
@test b.internal == Set([:A])
@test b.external == Set([:Integer])

@static if VERSION >= v"0.6"
    @test @valid_method f{A>:Integer}(::Type{A}) = A
end
b = Bindings()
ingest_parametric!(b, :(A>:Integer))
@test b.internal == Set([:A])
@test b.external == Set([:Integer])

@static if VERSION >= v"0.6"
    @test @valid_method f{Integer<:A<:Real}(::Type{A}) = A
end
b = Bindings()
ingest_parametric!(b, :(Integer<:A<:Real))
@test b.internal == Set([:A])
@test b.external == Set([:Integer, :Real])

@test @valid_method f{Int<:Integer}(x::Int) = x

# Invalid parametric
if VERSION >= v"0.6"
    method_expr = quote
        f{Integer<:A}(::Type{A}) = A
    end
    @test !valid_method(method_expr)
end
b = Bindings()
ingest_parametric!(b, :(Integer<:A))
@test b.internal == Set([:Integer])
@test b.external == Set([:A])

@static if VERSION >= v"0.6"
    method_expr = quote
        f{Integer>:A}(::Type{A}) = A
    end
    @test !valid_method(method_expr)
end
b = Bindings()
ingest_parametric!(b, :(Integer>:A))
@test b.internal == Set([:Integer])
@test b.external == Set([:A])

@static if VERSION >= v"0.6"
    @test !@valid_method f{Integer>:A}(::Type{A}) = A
end
b = Bindings()
ingest_parametric!(b, :(Integer>:A))
@test b.internal == Set([:Integer])
@test b.external == Set([:A])

@static if VERSION >= v"0.6"
    @test !@valid_method f{Int<:A>:Int}(::Type{A}) = A
end
@test_throws Exception ingest_parametric!(Bindings(), :(Int<:A>:Int))

@static if VERSION >= v"0.6"
    @test !@valid_method f{Int>:A<:Int}(::Type{A}) = A
end
@test_throws Exception ingest_parametric!(Bindings(), :(Int>:A<:Int))

@static if VERSION >= v"0.6"
    @test !@valid_method f{Int<:A<:Real<:Number}(::Type{A}) = A
end
@test_throws Exception ingest_parametric!(Bindings(), :(Int<:A<:Real<:Number))
