using Mocking
Mocking.enable(force=true)

using Compat: @__MODULE__
using Compat.Test
import Compat: Dates
import Mocking: apply

const INT_EXPR = Int === Int32 ? :(Core.Int32) : :(Core.Int64)
const HOUR_EXPR = VERSION < v"0.7.0-DEV.2575" ? :(Base.Dates.Hour) : :(Dates.Hour)
const RAND_EXPR = VERSION < v"0.7.0-DEV.3406" ? :(Base.Random.rand) : :(Random.rand)
const RAND_MOD_EXPR = VERSION < v"0.7.0-DEV.3406" ? :(Base.Random) : :Random

function next_gensym(str::AbstractString, offset::Integer=1)
    m = match(r"^(.*?)(\d+)$", string(gensym(str)))
    return Symbol(string(m.captures[1], parse(Int, m.captures[2]) + offset))
end


testfiles = [
#      "expr.jl",
 #   "bindings/bindings.jl",
  #  "patch.jl",

    "concept.jl",
    "closure.jl",
    "scope.jl",
    #"import.jl",
    "real-open.jl",
    "real-isfile.jl",
    "real-nested.jl",
    "mock-methods.jl",
    "readme.jl",
    #"optional.jl",
   # "patch-gen.jl",
    # "anonymous-param.jl",
]


@testset "Mocking" begin
    @testset "$file" for file in testfiles
        include(file)
    end
end
