# Needs to be in a separate file since not even `@static` can fix the unhandled syntax
import Mocking: Bindings, ingest_signature!

@test @valid_method f(x::T, y::S) where S<:T where T = (x, y)
b = Bindings()
ingest_signature!(b, :(f(x::T, y::S) where S<:T where T = (x, y)).args[1])
@test b.internal == Set([:f, :T, :S, :x, :y])
@test b.external == Set()

@test @valid_method f(x::T, y::S) where {T,S<:T} = (x, y)
b = Bindings()
ingest_signature!(b, :(f(x::T, y::S) where {T,S<:T} = (x, y)).args[1])
@test b.internal == Set([:f, :T, :S, :x, :y])
@test b.external == Set()
