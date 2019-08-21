@testset "type_morespecific" begin
    @testset "subtype" begin
        @test type_morespecific(Int, Integer)
        @test !type_morespecific(Integer, Int)
        @test !type_morespecific(Int, Int)
    end

    @testset "number of arguments" begin
        @test type_morespecific(Tuple{Int,AbstractFloat}, Tuple{Integer})
    end

    @testset "ambiguous" begin
        @test !type_morespecific(Tuple{Int,AbstractFloat}, Tuple{Integer,Float64})
        @test !type_morespecific(Tuple{Integer,Float64}, Tuple{Int,AbstractFloat})
    end

    @testset "length" begin
        @test type_morespecific(Tuple{Int,Int}, Tuple{Int,Vararg{Int}})
    end

    @testset "union" begin
        @test type_morespecific(Tuple{Int}, Tuple{Union{Int,Float64}})
        @test type_morespecific(Tuple{Union{Int,Float64}}, Tuple{Integer})
    end

    @testset "union all" begin
        @test type_morespecific(Tuple{Int}, Tuple{T} where T <: Integer)

        @test !type_morespecific(Tuple{Integer}, Tuple{T} where T <: Integer)
        @test !type_morespecific(Tuple{T} where T <: Integer, Tuple{Integer})

        @test type_morespecific(Tuple{Type{Integer}}, Tuple{Type{T}} where T <: Integer)
        @test !type_morespecific(Tuple{Type{T}} where T <: Integer, Tuple{Type{Integer}})
    end
end

@testset "anonymous_signature" begin
    @testset "diagonal dispatch" begin
        diag(::T, ::T) where T <: Integer = nothing

        diag_method = first(methods(diag, (Int, Int)))
        diag_sig = Tuple{typeof(diag),T,T} where T <: Integer
        @test diag_method.sig == diag_sig

        @test anonymous_signature(Tuple{typeof(diag),Int,Int}) == Tuple{Int,Int}
        @test anonymous_signature(diag_sig) == Tuple{T,T} where T <: Integer
        @test anonymous_signature(diag_method) == Tuple{T,T} where T <:Integer
    end

    @testset "triangular dispatch" begin
        tri(::Vector{T}, ::S) where {T, S<:T} = nothing

        tri_method = first(methods(tri, (Vector, Int)))
        tri_sig = Tuple{typeof(tri),Vector{T},S} where {T, S<:T}
        @test tri_method.sig == tri_sig

        @test anonymous_signature(Tuple{typeof(tri),Vector,Int}) == Tuple{Vector,Int}
        @test anonymous_signature(tri_sig) == Tuple{Vector{T},S} where {T, S<:T}
        @test anonymous_signature(tri_method) == Tuple{Vector{T},S} where {T, S<:T}
    end
end

@testset "anon_morespecific" begin
    plus_method = first(methods(+, (Int, Int)))
    max_method = first(methods(max, (Int, Int)))

    @test !type_morespecific(plus_method.sig, max_method.sig)
    @test anon_morespecific(plus_method, max_method)
end

@testset "dispatch" begin
    @testset "no functions" begin
        m, f = dispatch(Function[])
        @test f === nothing
        @test m === nothing
    end

    @testset "more specific function" begin
        funcs = [
            (::Int) -> 1
            (::Integer) -> 2
        ]

        m, f = dispatch(funcs, zero(Int))
        @test f == funcs[1]
        @test m.sig == Tuple{typeof(funcs[1]), Int}


        m, f = dispatch(funcs, zero(UInt))
        @test f == funcs[2]
        @test m.sig == Tuple{typeof(funcs[2]), Integer}
    end

    @testset "more specific method" begin
        f1(::Number) = 1
        f1(::Int) = 2
        f2(::Any) = 3
        f2(::Integer) = 4
        funcs = [f1, f2]

        m, f = dispatch(funcs, zero(Int))
        @test f == funcs[1]
        @test m.sig == Tuple{typeof(funcs[1]), Int}

        m, f = dispatch(funcs, zero(UInt))
        @test f == funcs[2]
        @test m.sig == Tuple{typeof(funcs[2]), Integer}
    end

    @testset "ambiguous" begin
        funcs = [
            (::Integer) -> 1
            (::Integer) -> 2
        ]

        # In ambiguous cases the last function is preferred
        m, f = dispatch(funcs, 0)
        @test f == funcs[2]
        @test m.sig == Tuple{typeof(funcs[2]), Integer}

        m, f = dispatch(reverse(funcs), 0)
        @test f == funcs[1]
        @test m.sig == Tuple{typeof(funcs[1]), Integer}
    end

    @testset "optional" begin
        funcs = [
            (x, y=0) -> 1
            (x) -> 2
        ]

        m, f = dispatch(funcs, 0)
        @test f == funcs[2]
        @test m.sig == Tuple{typeof(funcs[2]), Any}

        m, f = dispatch(funcs, 0, 0)
        @test f == funcs[1]
        @test m.sig == Tuple{typeof(funcs[1]), Any, Any}

        m, f = dispatch(reverse(funcs), 0)
        @test f == funcs[1]
        @test m.sig == Tuple{typeof(funcs[1]), Any}
    end

    @testset "Type{T}" begin
        funcs = [
            (::Type{Integer}) -> 1
            (::Type{Int}) -> 2
        ]

        m, f = dispatch(funcs, 0)
        @test f === nothing
        @test m === nothing

        m, f = dispatch(funcs, Integer)
        @test f == funcs[1]
        @test m.sig == Tuple{typeof(funcs[1]), Type{Integer}}

        m, f = dispatch(reverse(funcs), Type{Integer})
        @test f === nothing
        @test m === nothing
    end

    @testset "Type{T} where T" begin
        funcs = [
            (::Type{Int}) -> 1
            (::Type{<:Integer}) -> 2
        ]

        m, f = dispatch(funcs, Int)
        @test f == funcs[1]
        @test m.sig == Tuple{typeof(funcs[1]), Type{Int}}

        m, f = dispatch(reverse(funcs), Integer)
        @test f == funcs[2]
        @test m.sig == Tuple{typeof(funcs[2]), Type{<:Integer}}
    end
end
