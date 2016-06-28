# Mocking

[![Build Status](https://travis-ci.org/invenia/Mocking.jl.svg?branch=master)](https://travis-ci.org/invenia/Mocking.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/la041r86v6p5k24x?svg=true)](https://ci.appveyor.com/project/omus/mocking-jl)
[![codecov.io](http://codecov.io/github/invenia/Mocking.jl/coverage.svg?branch=master)](http://codecov.io/github/invenia/Mocking.jl?branch=master)

Allows Julia function calls to be temporarily overloaded for purpose of testing.


## Usage

Suppose you wrote the function `randdev`, how would you go about writing tests for it?

```julia
function randdev(n::Integer)
    open("/dev/urandom") do fp
        reverse(read(fp, n))
    end
end
```

The non-deterministic behaviour of this function makes it hard to test but we could write
some tests:

```julia
using Base.Test

include("...")

result = randdev(10)
@test eltype(result) == UInt8
@test length(result) == 10
```

But how could we test to ensure that the results produced by the function are reversed? The
Mocking.jl package provides developers with the `@mock` macro which allows them to 
temporarily overload a specific call. In this case we will apply `@mock` to the `open` call
in `randdev`:

```julia
function randdev(n::Integer)
    @mock open("/dev/urandom") do fp
        reverse(read(fp, n))
    end
end
```

With the call site being marked we can now write a new testcase which allows us to test
the reversing behaviour of the `randdev` function:

```julia
ENV["JULIA_TEST"] = 1
using Mocking

...

data = unsafe_string(pointer(convert(Array{UInt8}, 1:10)))  # Produces exactly 10 values

# Generate a alternative method of the `open` call we wish to mock.
patch = @patch open(fn::Function, f::AbstractString) = fn(IOBuffer(data))

# Apply the patch which will modify the behaviour for our test.
apply(patch) do
    @test randdev(10) == convert(Array{UInt8}, 10:-1:1)
end
```
