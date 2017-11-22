import Mocking: Bindings, ingest_assertion!

@testset "assertion" begin
    b = Bindings([:T], [])
    ingest_assertion!(b, :T)
    @test b.internal == Set([:T])
    @test b.external == Set()

    b = Bindings()
    ingest_assertion!(b, :Int)
    @test b.internal == Set()
    @test b.external == Set([:Int])

    b = Bindings()
    ingest_assertion!(b, :(Union{}))
    @test b.internal == Set()
    @test b.external == Set([:Union])

    b = Bindings()
    ingest_assertion!(b, :(Tuple{Int,Integer}))
    @test b.internal == Set()
    @test b.external == Set([:Tuple, :Int, :Integer])

    b = Bindings([:T], [])
    ingest_assertion!(b, :(AbstractArray{T,1}))
    @test b.internal == Set([:T])
    @test b.external == Set([:AbstractArray])

    b = Bindings()
    ingest_assertion!(b, :(AbstractArray{<:Integer}))
    @test b.internal == Set([])
    @test b.external == Set([:AbstractArray, :Integer])

    b = Bindings()
    ingest_assertion!(b, :(AbstractArray{>:Integer}))
    @test b.internal == Set([])
    @test b.external == Set([:AbstractArray, :Integer])

    b = Bindings()
    ingest_assertion!(b, :(<:Integer))  # Should throw and exception
    @test b.internal == Set([])
    @test b.external == Set([:Integer])

    b = Bindings()
    ingest_assertion!(b, :Hour)
    @test b.internal == Set([])
    @test b.external == Set([:Hour])

    b = Bindings()
    ingest_assertion!(b, :(Dates.Hour))
    @test b.internal == Set([])
    @test b.external == Set([:(Dates.Hour)])

    b = Bindings()
    ingest_assertion!(b, :(Base.Dates.Hour))
    @test b.internal == Set([])
    @test b.external == Set([:(Base.Dates.Hour)])

    b = Bindings()
    ingest_assertion!(b, :(typeof(cos)))
    @test b.internal == Set([])
    @test b.external == Set([:typeof, :cos])
end
