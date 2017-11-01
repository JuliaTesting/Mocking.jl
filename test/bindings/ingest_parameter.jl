import Mocking: Bindings, ingest_parameter!

@testset "parameters" begin
    b = Bindings()
    ingest_parameter!(b, :a)
    @test b.internal == Set([:a])
    @test b.external == Set([])

    b = Bindings()
    ingest_parameter!(b, :(a::Int))
    @test b.internal == Set([:a])
    @test b.external == Set([:Int])

    b = Bindings()
    ingest_parameter!(b, :(a::Union{}))
    @test b.internal == Set([:a])
    @test b.external == Set([:Union])

    b = Bindings()
    ingest_parameter!(b, :(a::Tuple{Int,Integer}))
    @test b.internal == Set([:a])
    @test b.external == Set([:Tuple, :Int, :Integer])

    b = Bindings()
    ingest_parameter!(b, :(f(a=1)).args[2])
    @test b.internal == Set([:a])
    @test b.external == Set([])

    b = Bindings()
    ingest_parameter!(b, :(f(a=rand())).args[2])
    @test b.internal == Set([:a])
    @test b.external == Set([:rand])

    b = Bindings()
    ingest_parameter!(b, :(f(a::Int=1)).args[2])
    @test b.internal == Set([:a])
    @test b.external == Set([:Int])

    b = Bindings()
    ingest_parameter!(b, :(f(; a=1)).args[2])  # VERSION >= v"0.5-" could be `:(; a=1).args[1]`
    @test b.internal == Set([:a])
    @test b.external == Set([])

    b = Bindings()
    ingest_parameter!(b, :(f(; a::Int=1)).args[2])  # VERSION >= v"0.5-" could be `:(; a::Int=1).args[1]`
    @test b.internal == Set([:a])
    @test b.external == Set([:Int])

    b = Bindings()
    ingest_parameter!(b, :(f(a...)).args[2])
    @test b.internal == Set([:a])
    @test b.external == Set([])

    b = Bindings()
    ingest_parameter!(b, :(f(a::Int...)).args[2])
    @test b.internal == Set([:a])
    @test b.external == Set([:Int])

    b = Bindings()
    ingest_parameter!(b, :(f(a::Int=rand(Int)...)).args[2])
    @test b.internal == Set([:a])
    @test b.external == Set([:Int, :rand])

    b = Bindings()
    ingest_parameter!(b, :(f(; a::Int=rand(Int)...)).args[2])
    @test b.internal == Set([:a])
    @test b.external == Set([:Int, :rand])
end
