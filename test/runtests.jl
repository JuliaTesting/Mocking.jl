using Mocking

using Test
import Dates
using Dates: Hour
using Mocking: apply


function next_gensym(str::AbstractString, offset::Integer=1)
    m = match(r"^(.*?)(\d+)$", string(gensym(str)))
    return Symbol(string(m.captures[1], parse(Int, m.captures[2]) + offset))
end


testfiles = [
    "deprecations.jl",

    "expr.jl",
    "bindings/bindings.jl",
    "patch.jl",

    "concept.jl",
    "closure.jl",
    "scope.jl",
    "import.jl",
    "real-open.jl",
    "real-isfile.jl",
    "real-nested.jl",
    "mock-methods.jl",
    "readme.jl",
    "patch-gen.jl",
    "anonymous-param.jl",

    "optional.jl",
]


@testset "Mocking" begin
    @testset "$file" for file in testfiles
        include(file)
    end
end
