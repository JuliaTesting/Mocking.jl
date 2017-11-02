import Mocking: Bindings, ingest_parametric!

# Note: The `f{A}` parametric syntax and `where` are equal when looking at individual
# components.

@testset "parametric" begin
    @test @valid_method f(::Type{A}) where A = A
    b = Bindings()
    ingest_parametric!(b, :A)
    @test b.internal == Set([:A])
    @test b.external == Set([])

    @test @valid_method f(::Type{A}, ::Type{B}) where {A,B<:A} = A, B
    ingest_parametric!(b, :(B<:A))
    @test b.internal == Set([:A, :B])
    @test b.external == Set([])

    @test @valid_method f(::Type{A}) where {A<:Integer} = A
    b = Bindings()
    ingest_parametric!(b, :(A<:Integer))
    @test b.internal == Set([:A])
    @test b.external == Set([:Integer])

    @test @valid_method f(::Type{A}) where {A>:Integer} = A
    b = Bindings()
    ingest_parametric!(b, :(A>:Integer))
    @test b.internal == Set([:A])
    @test b.external == Set([:Integer])

    @test @valid_method f(::Type{A}) where {Integer<:A<:Real} = A
    b = Bindings()
    ingest_parametric!(b, :(Integer<:A<:Real))
    @test b.internal == Set([:A])
    @test b.external == Set([:Integer, :Real])

    @test @valid_method f(x::Int) where {Int<:Integer} = x
    b = Bindings()
    ingest_parametric!(b, :(Int<:Integer))
    @test b.internal == Set([:Int])
    @test b.external == Set([:Integer])

    # Invalid parametric
    method_expr = quote
        f(::Type{A}) where {Integer<:A} = A
    end
    @test !valid_method(method_expr)
    b = Bindings()
    ingest_parametric!(b, :(Integer<:A))
    @test b.internal == Set([:Integer])
    @test b.external == Set([:A])

    method_expr = quote
        f(::Type{A}) where {Integer>:A} = A
    end
    @test !valid_method(method_expr)
    b = Bindings()
    ingest_parametric!(b, :(Integer>:A))
    @test b.internal == Set([:Integer])
    @test b.external == Set([:A])

    @test !@valid_method f(::Type{A}) where {Integer>:A} = A
    b = Bindings()
    ingest_parametric!(b, :(Integer>:A))
    @test b.internal == Set([:Integer])
    @test b.external == Set([:A])

    @test !@valid_method f(::Type{A}) where {Int<:A>:Int} = A
    @test_throws Exception ingest_parametric!(Bindings(), :(Int<:A>:Int))

    @test !@valid_method f(::Type{A}) where {Int>:A<:Int} = A
    @test_throws Exception ingest_parametric!(Bindings(), :(Int>:A<:Int))

    @test !@valid_method f(::Type{A}) where {Int<:A<:Real<:Number} = A
    @test_throws Exception ingest_parametric!(Bindings(), :(Int<:A<:Real<:Number))
end
