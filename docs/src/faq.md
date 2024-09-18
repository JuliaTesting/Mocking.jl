# FAQ

```@meta
CurrentModule = Mocking
```

## What kind of overhead does `@mock` add?

The [`@mock`](@ref) macro is a no-op and has zero overhead when mocking has not been activated via
[`Mocking.activate()`](@ref activate). Users can use `@code_llvm` on their code with and without `@mock` to
confirm the macro has no effect.

When `Mocking.activate` is called Mocking.jl will re-define a function utilized by `@mock`
which results in invalidating any functions using the macro. The result of this is that when
running your tests will cause those functions to be recompiled the next time they are called
such that the alternative code path provided by patches can be executed.

## Why isn't my patch being called?

When your patch isn't being applied you should remember to check for the following:

- [`Mocking.activate`](@ref activate) is called before the [`apply`](@ref) call.
- Call sites you want to patch are using [`@mock`](@ref).
- The patch's argument types are supertypes the values passed in at the call site.

You can also start Julia with `JULIA_DEBUG=Mocking` to show details about what methods are
being dispatched to from `@mock`ed call sites. These interception messages are only
displayed if `Mocking.activate` has been called.

## Where should I add `Mocking.activate()`?

We recommend putting the call to [`Mocking.activate`](@ref activate) in your package's
`test/runtests.jl` file after all of your import statements. The only true requirement is
that you call  `Mocking.activate()` before the first [`apply`](@ref) call.

## What if I want to call the un-patched function inside a patch?

Simply call the patched function without `@mock`:

```julia
julia> f(x) = x + 1
f (generic function with 1 method)

julia> g(x) = @mock(f(x)) * 2
g (generic function with 1 method)

julia> fp = @patch f(x) = f(-x)
Patch{typeof(f)}(f, var"##f_patch#240")

julia> g(3)
8 # = (3 + 1) * 2

julia> apply(fp) do 
           g(3)
       end
-4 # = (-3 + 1) * 2
```

Note that you can also use `@mock` _inside_ a patch, which can be useful when using
multiple dispatch with patches.
