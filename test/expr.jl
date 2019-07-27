macro audit(expr::Expr)
    result = quote
        tuple(
            try
                @eval let
                    $expr
                end
            catch e
                e
            end,
            $(QuoteNode(expr)),
        )
    end
    return esc(result)
end

function strip_lineno!(expr::Expr)
    filter!(expr.args) do ex
        isa(ex, LineNumberNode) && return false
        if isa(ex, Expr)
            ex.head === :line && return false
            strip_lineno!(ex::Expr)
        end
        return true
    end
    return expr
end

macro test_splitdef_invalid(expr)
    result = quote
        @test_throws ArgumentError splitdef($expr)
        @test splitdef($expr, throw=false) === nothing
    end
    return esc(result)
end

@testset "splitdef" begin
    @testset "long-form function" begin
        f, expr = @audit function f() end
        @test length(methods(f)) == 1
        @test f() === nothing

        d = splitdef(expr)
        @test keys(d) == Set([:type, :name, :body])
        @test d[:type] == :function
        @test d[:name] == :f
        @test strip_lineno!(d[:body]) == Expr(:block)
    end

    @testset "short-form function" begin
        f, expr = @audit f() = nothing
        @test length(methods(f)) == 1
        @test f() === nothing

        d = splitdef(expr)
        @test keys(d) == Set([:type, :name, :body])
        @test d[:type] == :(=)
        @test d[:name] == :f
        @test strip_lineno!(d[:body]) == Expr(:block, :nothing)
    end

    @testset "anonymous function" begin
        f, expr = @audit () -> nothing
        @test length(methods(f)) == 1
        @test f() === nothing

        d = splitdef(expr)
        @test keys(d) == Set([:type, :body])
        @test d[:type] == :(->)
        @test strip_lineno!(d[:body]) == Expr(:block, :nothing)
    end

    @testset "empty function" begin
        f, expr = @audit function f end
        @test length(methods(f)) == 0

        d = splitdef(expr)
        @test keys(d) == Set([:type, :name])
        @test d[:type] == :function
        @test d[:name] == :f
    end

    @testset "args (short-form function)" begin
        @testset "f(x)" begin
            f, expr = @audit f(x) = x
            @test length(methods(f)) == 1
            @test f(0) == 0

            d = splitdef(expr)
            @test keys(d) == Set([:type, :name, :args, :body])
            @test d[:args] == [:x]
        end

        @testset "f(x::Integer)" begin
            f, expr = @audit f(x::Integer) = x
            @test length(methods(f)) == 1
            @test f(0) == 0

            d = splitdef(expr)
            @test keys(d) == Set([:type, :name, :args, :body])
            @test d[:args] == [:(x::Integer)]
        end

        @testset "f(x=1)" begin
            f, expr = @audit f(x=1) = x
            @test length(methods(f)) == 2
            @test f(0) == 0
            @test f() == 1

            d = splitdef(expr)
            @test keys(d) == Set([:type, :name, :args, :body])
            @test d[:args] == [Expr(:kw, :x, 1)]
        end

        @testset "f(x::Integer=1)" begin
            f, expr = @audit f(x::Integer=1) = x
            @test length(methods(f)) == 2
            @test f(0) == 0
            @test f() == 1

            d = splitdef(expr)
            @test keys(d) == Set([:type, :name, :args, :body])
            @test d[:args] == [Expr(:kw, :(x::Integer), 1)]
        end
    end

    @testset "args (anonymous function)" begin
        @testset "x" begin
            f, expr = @audit x -> x
            @test length(methods(f)) == 1
            @test f(0) == 0

            d = splitdef(expr)
            @test keys(d) == Set([:type, :args, :body])
            @test d[:args] == [:x]
        end

        @testset "x::Integer" begin
            f, expr = @audit x::Integer -> x
            @test length(methods(f)) == 1
            @test f(0) == 0

            d = splitdef(expr)
            @test keys(d) == Set([:type, :args, :body])
            @test d[:args] == [:(x::Integer)]
        end

        @testset "(x=1)" begin
            f, expr = @audit (x=1) -> x
            @test length(methods(f)) == 2
            @test f(0) == 0
            @test f() == 1

            d = splitdef(expr)
            @test keys(d) == Set([:type, :args, :body])
            @test d[:args] == [:(x=1)]
        end

        @testset "(x::Integer=1)" begin
            f, expr = @audit (x::Integer=1) -> x
            @test length(methods(f)) == 2
            @test f(0) == 0
            @test f() == 1

            d = splitdef(expr)
            @test keys(d) == Set([:type, :args, :body])
            @test d[:args] == [:(x::Integer=1)]
        end

        @testset "(x,)" begin
            f, expr = @audit (x,) -> x
            @test length(methods(f)) == 1
            @test f(0) == 0

            d = splitdef(expr)
            @test keys(d) == Set([:type, :args, :body])
            @test d[:args] == [:x]
        end

        @testset "(x::Integer,)" begin
            f, expr = @audit (x::Integer,) -> x
            @test length(methods(f)) == 1
            @test f(0) == 0

            d = splitdef(expr)
            @test keys(d) == Set([:type, :args, :body])
            @test d[:args] == [:(x::Integer)]
        end

        @testset "(x=1,)" begin
            f, expr = @audit (x=1,) -> x
            @test length(methods(f)) == 2
            @test f(0) === 0
            @test f() === 1

            d = splitdef(expr)
            @test keys(d) == Set([:type, :args, :body])
            @test d[:args] == [:(x=1)]
        end

        @testset "(x::Integer=1,)" begin
            f, expr = @audit (x::Integer=1,) -> x
            @test length(methods(f)) == 2
            @test f(0) == 0
            @test f() == 1

            d = splitdef(expr)
            @test keys(d) == Set([:type, :args, :body])
            @test d[:args] == [:(x::Integer=1)]
        end
    end

    @testset "kwargs (short-form function)" begin
        @testset "f(; x)" begin
            f, expr = @audit f(; x) = x
            @test length(methods(f)) == 1
            @test f(x=0) == 0

            d = splitdef(expr)
            @test keys(d) == Set([:type, :name, :kwargs, :body])
            @test d[:kwargs] == [:x]
        end

        @testset "f(; x::Integer)" begin
            f, expr = @audit f(; x::Integer) = x
            @test length(methods(f)) == 1
            @test f(x=0) == 0

            d = splitdef(expr)
            @test keys(d) == Set([:type, :name, :kwargs, :body])
            @test d[:kwargs] == [:(x::Integer)]
        end

        @testset "f(; x=1)" begin
            f, expr = @audit f(; x=1) = x
            @test length(methods(f)) == 1
            @test f(x=0) == 0

            d = splitdef(expr)
            @test keys(d) == Set([:type, :name, :kwargs, :body])
            @test d[:kwargs] == [Expr(:kw, :x, 1)]
        end

        @testset "f(; x::Integer=1)" begin
            f, expr = @audit f(; x::Integer=1) = x
            @test length(methods(f)) == 1
            @test f(x=0) == 0

            d = splitdef(expr)
            @test keys(d) == Set([:type, :name, :kwargs, :body])
            @test d[:kwargs] == [Expr(:kw, :(x::Integer), 1)]
        end
    end

    @testset "kwargs (anonymous function)" begin
        @testset "(; x)" begin
            f, expr = @audit (; x) -> x
            @test length(methods(f)) == 1
            @test f(x=0) == 0

            d = splitdef(expr)
            @test keys(d) == Set([:type, :kwargs, :body])
            @test d[:kwargs] == [:x]
        end

        @testset "(; x::Integer)" begin
            f, expr = @audit (; x::Integer) -> x
            @test length(methods(f)) == 1
            @test f(x=0) == 0

            d = splitdef(expr)
            @test keys(d) == Set([:type, :kwargs, :body])
            @test d[:kwargs] == [:(x::Integer)]
        end

        @testset "(; x=1)" begin
            f, expr = @audit (; x=1) -> x
            @test length(methods(f)) == 1
            @test f(x=0) == 0

            d = splitdef(expr)
            @test keys(d) == Set([:type, :kwargs, :body])
            @test d[:kwargs] == [Expr(:kw, :x, 1)]
        end

        @testset "(; x::Integer=1)" begin
            f, expr = @audit (; x::Integer=1) -> x
            @test length(methods(f)) == 1
            @test f(x=0) == 0

            d = splitdef(expr)
            @test keys(d) == Set([:type, :kwargs, :body])
            @test d[:kwargs] == [Expr(:kw, :(x::Integer), 1)]
        end
    end

    @testset "where (short-form function)" begin
        @testset "single where" begin
            f, expr = @audit f(::A) where A = nothing
            @test length(methods(f)) == 1

            d = splitdef(expr)
            @test keys(d) == Set([:type, :name, :args, :whereparams, :body])
            @test d[:whereparams] == [:A]
        end

        @testset "curly where" begin
            f, expr = @audit f(::A, ::B) where {A, B <: A} = nothing
            @test length(methods(f)) == 1

            d = splitdef(expr)
            @test keys(d) == Set([:type, :name, :args, :whereparams, :body])
            @test d[:whereparams] == [:A, :(B <: A)]
        end

        @testset "multiple where" begin
            f, expr = @audit f(::A, ::B) where B <: A where A = nothing
            @test length(methods(f)) == 1

            d = splitdef(expr)
            @test keys(d) == Set([:type, :name, :args, :whereparams, :body])
            @test d[:whereparams] == [:A, :(B <: A)]
        end
    end

    @testset "where (anonymous function)" begin
        @testset "where" begin
            f, expr = @audit ((::A) where A) -> nothing
            @test length(methods(f)) == 1

            d = splitdef(expr)
            @test keys(d) == Set([:type, :args, :whereparams, :body])
            @test d[:whereparams] == [:A]
        end

        @testset "curly where" begin
            f, expr = @audit ((::A, ::B) where {A, B <: A}) -> nothing
            @test length(methods(f)) == 1

            d = splitdef(expr)
            @test keys(d) == Set([:type, :args, :whereparams, :body])
            @test d[:whereparams] == [:A, :(B <: A)]
        end

        @testset "multiple where" begin
            f, expr = @audit ((::A, ::B) where B <: A where A) -> nothing
            @test length(methods(f)) == 1

            d = splitdef(expr)
            @test keys(d) == Set([:type, :args, :whereparams, :body])
            @test d[:whereparams] == [:A, :(B <: A)]
        end
    end

    @testset "return-type (short-form function)" begin
        @testset "f(x)::Integer" begin
            f, expr = @audit f(x)::Integer = x
            @test length(methods(f)) == 1
            @test f(0.0) isa Integer

            d = splitdef(expr)
            @test keys(d) == Set([:type, :name, :args, :rtype, :body])
            @test d[:rtype] == :Integer

        end

        @testset "(f(x::T)::Integer) where T" begin
            f, expr = @audit (f(x::T)::Integer) where T = x
            @test length(methods(f)) == 1
            @test f(0.0) isa Integer

            d = splitdef(expr)
            @test keys(d) == Set([:type, :name, :args, :rtype, :whereparams, :body])
            @test d[:rtype] == :Integer
        end
    end

    @testset "return-type (anonymous function)" begin
        @testset "(x,)::Integer" begin
            f, expr = @audit (x,)::Integer -> x  # Julia interprets this as `(x::Integer,) -> x`
            @test length(methods(f)) == 1
            @test f(0) == 0
            @test_throws MethodError f(0.0)

            d = splitdef(expr)
            @test keys(d) == Set([:type, :args, :body])
            @test d[:args] == [:((x,)::Integer)]
        end

        @testset "(((x::T,)::Integer) where T)" begin
            f, expr = @audit (((x::T,)::Integer) where T) -> x
            @test f isa ErrorException

            @test_broken splitdef(expr, throw=false) === nothing
        end
    end

    @testset "invalid definitions" begin
        # Invalid function type
        @test_splitdef_invalid Expr(:block)

        # Too few expression arguments
        @test_splitdef_invalid Expr(:function)
        @test_splitdef_invalid Expr(:(=), :f)

        # Too many expression arguments
        @test_splitdef_invalid Expr(:function, :f, :x, :y)
        @test_splitdef_invalid Expr(:(=), :f, :x, :y)

        # Invalid or missing arguments
        @test_splitdef_invalid :(f{S} = 0)
        @test_splitdef_invalid Expr(:function, Expr(:tuple, :f), :(nothing))
    end
end
