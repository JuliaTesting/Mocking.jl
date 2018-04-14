import Mocking: Bindings, ingest_default!

@testset "default" begin
    b = Bindings()
    ingest_default!(b, :(1))
    @test b.internal == Set()
    @test b.external == Set()

    b = Bindings()
    ingest_default!(b, :Int)
    @test b.internal == Set()
    @test b.external == Set([:Int])

    b = Bindings()
    ingest_default!(b, :(f(rand(Bool))))
    @test b.internal == Set()
    @test b.external == Set([:f, :rand, :Bool])

    b = Bindings()
    ingest_default!(b, :(f(rand(Base.Bool))))
    @test b.internal == Set()
    @test b.external == Set([:f, :rand, :(Base.Bool)])

    b = Bindings()
    ingest_default!(b, :(f([Base.Bool])))
    @test b.internal == Set()
    @test b.external == Set([:f, :(Base.Bool)])

    b = Bindings()
    ingest_default!(b, :(f((Base.Bool,))))
    @test b.internal == Set()
    @test b.external == Set([:f, :(Base.Bool)])
end
