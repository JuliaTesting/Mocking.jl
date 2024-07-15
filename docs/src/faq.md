# FAQ

```@meta
CurrentModule = Mocking
```

## Why isn't my patch being called?

When your patch isn't being applied you should remember to check for the following:

- [`Mocking.activate`](@ref activate) is called before the [`apply`](@ref) call.
- Call sites you want to patch are using [`@mock`](@ref).
- The patch's argument types are supertypes the values passed in at the call site.

## What kind of overhead does `@mock` add?

The [`@mock`](@ref) macro is a no-op and has zero overhead when mocking has not been activated via
[`Mocking.activate()`](@ref activate). Users can use `@code_llvm` on their code with and without `@mock` to
confirm the macro has no effect.

When `Mocking.activate` is called Mocking.jl will re-define a function utilized by `@mock`
which results in invalidating any functions using the macro. The result of this is that when
running your tests will cause those functions to be recompiled the next time they are called
such that the alternative code path provided by patches can be executed.
