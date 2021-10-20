Mocking
=======

[![CI](https://github.com/Invenia/Mocking.jl/workflows/CI/badge.svg)](https://github.com/Invenia/Mocking.jl/actions?query=workflow%3ACI)
[![codecov.io](http://codecov.io/github/invenia/Mocking.jl/coverage.svg?branch=master)](http://codecov.io/github/invenia/Mocking.jl?branch=master)

[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle) 
[![ColPrac: Contributor Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)


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
**Simpler Example**

The fuction to be tested and mocked can be in a julia file as shown below:

```
function sub(x,y)
    return x*y
end

function addo(x,y)
    z = @mock sub(x,y)
return x+y+z
end
```

The test file is put in separate julia file as shown below:
```
using Test
using Mocking

include("../src/ToLoadData.jl")
Mocking.activate()


patch = @patch sub(x::Int64, y::Int64) = 0
apply(patch) do
    @test addo(1,1) == 2
end
```

Mocking creates an easier path for testing the function under test while having some expecttion and return value of other sub-functions




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
