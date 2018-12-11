__precompile__(true)

module Mocking
using MacroTools
using Cassette
using Cassette: @context


include("expr.jl")
include("bindings.jl")
include("deprecated.jl")
include("patch.jl")
include("patchenv.jl")


export
    # Mocking.jl
    @patch, Patch, apply,
    # deprecated.jl
    @mock



function ismocked(pe::PatchEnv, func_name::Symbol, args::Tuple)
    # TODO: redefine this in terms of `methodswith(pe.ctx, Cassette.execute...)`
    # If required
    error("`ismocked` is not implemented")
end
end # module
