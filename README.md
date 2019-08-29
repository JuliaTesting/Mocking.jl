Mocking
=======

[![Build Status](https://travis-ci.org/invenia/Mocking.jl.svg?branch=master)](https://travis-ci.org/invenia/Mocking.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/la041r86v6p5k24x?svg=true)](https://ci.appveyor.com/project/omus/mocking-jl)
[![codecov.io](http://codecov.io/github/invenia/Mocking.jl/coverage.svg?branch=master)](http://codecov.io/github/invenia/Mocking.jl?branch=master)

Allows Julia function calls to be temporarily overloaded for purpose of testing.

Contents
--------

- [Usage](#usage)
- [Gotchas](#gotchas)
- [Overhead](#overhead)

Usage
-----

Suppose you wrote the function `randdev` (UNIX only). How would you go about writing tests
for it?

```julia
function randdev(n::Integer)
    open("/dev/urandom") do fp
        reverse(read(fp, n))
    end
end
```

The non-deterministic behaviour of this function makes it hard to test but we can write some
tests dealing with the deterministic properties of the function:

```julia
using Test
using ...: randdev

n = 10
result = randdev(n)
@test eltype(result) == UInt8
@test length(result) == n
```

How could we create a test that shows the output of the function is reversed? Mocking.jl
provides the `@mock` macro which allows package developers to temporarily overload a
specific calls in their package. In this example we will apply `@mock` to the `open` call
in `randdev`:

```julia
using Mocking

function randdev(n::Integer)
    @mock open("/dev/urandom") do fp
        reverse(read(fp, n))
    end
end
```

With the call site being marked as "mockable" we can now write a testcase which allows
us to demonstrate the reversing behaviour within the `randdev` function:

```julia
using Mocking
using Test
using ...: randdev

Mocking.activate()  # Need to call `activate` before executing `apply`

n = 10
result = randdev(n)
@test eltype(result) == UInt8
@test length(result) == n

# Produces a string with sequential UInt8 values from 1:n
data = unsafe_string(pointer(convert(Array{UInt8}, 1:n)))

# Generate a alternative method of `open` which call we wish to mock
patch = @patch open(fn::Function, f::AbstractString) = fn(IOBuffer(data))

# Apply the patch which will modify the behaviour for our test
apply(patch) do
    @test randdev(n) == convert(Array{UInt8}, n:-1:1)
end

# Outside of the scope of the patched environment `@mock` is essentially a no-op
@test randdev(n) != convert(Array{UInt8}, n:-1:1)
```

Gotchas
-------

Remember to:

- Use `@mock` at desired call sites
- Run `Mocking.activate()` before executing any `apply` calls

Overhead
--------

The `@mock` macro uses a conditional check of `Mocking.activated()` which only allows
patches to be utilized only when Mocking has been activated. By default, Mocking starts as
disabled which should result conditional being optimized away allowing for zero-overhead.
Once activated via `Mocking.activate()` the `Mocking.activated` function will be
re-defined, causing all methods dependent on `@mock` to be recompiled.

License
-------

Mocking.jl is provided under the [MIT "Expat" License](LICENSE.md).