using Cassette: Cassette, @context

@context Context

# Note: these functions have been tweaked to maximize performance
iscallable(::Union{Function,Type}) = true

@generated function iscallable(::T) where T
    isdefined(T, :instance) || return :(false)
    mt = typeof(T.instance).name.mt
    return :(!isempty($mt))
end

function Cassette.overdub(ctx::Mocking.Context, @nospecialize(target), args...)
    alternate = if iscallable(target)
        get_alternate(ctx.metadata, target, args...)
    else
        nothing
    end

    if alternate !== nothing
        Cassette.overdub(ctx, alternate, args...)
        # alternate(args...)
        # Base.invokelatest(alternate, args...)
    elseif Cassette.canrecurse(ctx, target, args...)
        Cassette.recurse(ctx, target, args...)
    else
        Cassette.fallback(ctx, target, args...)
    end
end

# TODO: Enable overdubbing calls using keywords
#=
function Cassette.overdub(ctx::Mocking.Context, @nospecialize(kwfunc::Function), @nospecialize(kwargs), @nospecialize(target), args...)
    # Ensure that we are overdubbing a call to a function with keywords
    # TODO: Could possibly use a generated function to move this check to compile time
    if !(kwfunc isa Core.kwftype(typeof(target)))
        return invoke(Cassette.overdub, Tuple{Mocking.Context, Any, Vararg}, ctx, kwfunc, kwargs, target, args...)
    end

    alternate = if iscallable(target)
        get_alternate(ctx.metadata, target, args...)
    else
        nothing
    end

    if alternate !== nothing
        Cassette.overdub(ctx, Core.kwfunc(alternate), kwargs, alternate, args...)
        # alternate(args...; kwargs...)
    elseif Cassette.canrecurse(ctx, target, args...)
        Cassette.recurse(ctx, kwfunc, kwargs, target, args...)
    else
        Cassette.fallback(ctx, kwfunc, kwargs, target, args...)
    end
end
=#

# TODO: Support overdubbing calls inside of tasks
#=
function Cassette.overdub(ctx::Mocking.Context, ::typeof(Base.Core.Task), @nospecialize(f), stack::Int, future)
    Base.Core.Task(() -> Cassette.overdub(ctx, f), stack, future)
end
=#

function apply(::Injector{:CassetteStatic}, body::Function, patch_env::PatchEnv)
    ctx = Cassette.disablehooks(Context(metadata=patch_env))
    Base.invokelatest(Cassette.overdub, ctx, body)
end
