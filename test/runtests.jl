using Mocking
using Test

using Aqua: Aqua
using Dates: Dates, Hour
using Logging: Debug
using Mocking: anon_morespecific, anonymous_signature, apply, dispatch, type_morespecific

Mocking.activate()

@testset "Mocking" begin
    @testset "Code quality (Aqua.jl)" begin
        # Unable to add compat entries for stdlibs while we support Julia 1.0
        stdlibs = [:Dates, :Logging, :Test]
        Aqua.test_all(Mocking; deps_compat=(; check_extras=(; ignore=stdlibs)))
    end

    include("dispatch.jl")
    include("mock.jl")
    include("patch.jl")
    include("debug.jl")

    include("concept.jl")
    include("targets.jl")
    include("functions.jl")
    include("import.jl")
    include("real-open.jl")
    include("real-isfile.jl")
    include("real-nested.jl")
    include("mock-in-patch.jl")
    include("randdev.jl")
    include("optional.jl")
    include("patch-gen.jl")
    include("anonymous-param.jl")
    include("reuse.jl")
    include("args.jl")
    include("merge.jl")
    include("nested_apply.jl")
    include("async-scope.jl")
    include("issues.jl")
    include("activate.jl")
    include("async-world-ages.jl")
end
