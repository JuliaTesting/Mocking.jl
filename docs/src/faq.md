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

Simply call the function without using `@mock` within the patch. For example we can count the number of calls a recursive function does like this:

```julia
function fibonacci(n)
    if n <= 1
        return n
    else
        return @mock(fibonacci(n - 1)) + @mock(fibonacci(n - 2))
    end
end

calls = Ref(0)
p = @patch function fibonacci(n)
    calls[] += 1
    return fibonacci(n)  # Calls original function
end

apply(p) do
    @test @mock(fibonacci(1)) == 1
    @test calls[] == 1

    calls[] = 0
    @test @mock(fibonacci(4)) == 3
    @test calls[] == 9
end
```

Note that you can also use `@mock` _inside_ a patch, which can be useful when using
multiple dispatch with patches.
