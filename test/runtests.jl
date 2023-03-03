using Mocking
Mocking.activate()

using Dates: Dates, Hour
using Test

using Mocking: apply
using Mocking: anon_morespecific, anonymous_signature, dispatch, type_morespecific

@testset "Mocking" begin
    include("dispatch.jl")
    include("mock.jl")
    include("patch.jl")

    include("concept.jl")
    include("targets.jl")
    include("functions.jl")
    include("import.jl")
    include("real-open.jl")
    include("real-isfile.jl")
    include("real-nested.jl")
    include("mock-in-patch.jl")
    include("readme.jl")
    include("optional.jl")
    include("patch-gen.jl")
    include("anonymous-param.jl")
    include("reuse.jl")
    include("args.jl")
    include("merge.jl")
    include("nested_apply.jl")
    include("async.jl")
    include("issues.jl")
    include("activate.jl")
end
