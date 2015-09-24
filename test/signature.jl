# Test Patch.signature
let generic() = nothing
    @test_throws ArgumentError Patch.signature(generic)
end

@test Patch.signature(() -> nothing) == Tuple{}
@test Patch.signature((v) -> nothing) == Tuple{Any}
@test Patch.signature((v::Int64) -> nothing) == Tuple{Int64}
@test Patch.signature((v, n::AbstractString) -> nothing) == Tuple{Any,AbstractString}
@test Patch.signature((name...) -> nothing) == Tuple

# Tests for Patch.array
@test_throws ArgumentError Patch.array(Any)

@test Patch.array(Tuple{Any,AbstractArray{Int64,1}}) == Type[Any, AbstractArray{Int64,1}]
@test Patch.array(Tuple{}) == Type[]
@test Patch.array(Tuple) == Type[]
