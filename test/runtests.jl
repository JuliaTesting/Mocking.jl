using Mocking

if get(ENV, "MOCKING_INJECTOR", "") == "macro"
    Mocking.INJECTOR[] = Mocking.Injector{:MockMacro}()
elseif get(ENV, "MOCKING_INJECTOR", "") == "cassette-static"
    Mocking.INJECTOR[] = Mocking.Injector{:CassetteStatic}()
elseif get(ENV, "MOCKING_INJECTOR", "") == "cassette-code-gen"
    Mocking.INJECTOR[] = Mocking.Injector{:CassetteCodeGen}()
end

const INDIVIDUAL = get(ENV, "MOCKING_INDIVIDUAL", "false") == "true"

@info "Injector: $(Mocking.INJECTOR[])"
@info "Individual: $(INDIVIDUAL)"

if Mocking.INJECTOR[] == Mocking.Injector{:MockMacro}()
    Mocking.activate()
else
    Mocking.deactivate()
end

using Dates: Dates, Hour
using Test

using Mocking: apply, splitdef, combinedef
using Mocking: anon_morespecific, anonymous_signature, dispatch, type_morespecific

@testset "Mocking" begin
    # include("expr.jl")
    # include("dispatch.jl")
    include("patch.jl")

    # include("concept.jl")
    # include("targets.jl")

    # include("functions.jl")
    # include("import.jl")
    # include("real-open.jl")
    # include("real-isfile.jl")
    # include("real-nested.jl")
    include("mock-in-patch.jl")
    # include("readme.jl")
    # include("optional.jl")
    # include("patch-gen.jl")
    # include("anonymous-param.jl")
    # include("reuse.jl")
    # include("args.jl")
end
