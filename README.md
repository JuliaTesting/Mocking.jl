# Mocking

[![Build Status](https://travis-ci.org/invenia/Mocking.jl.svg?branch=master)](https://travis-ci.org/invenia/Mocking.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/la041r86v6p5k24x?svg=true)](https://ci.appveyor.com/project/omus/mocking-jl)
[![codecov.io](http://codecov.io/github/invenia/Mocking.jl/coverage.svg?branch=master)](http://codecov.io/github/invenia/Mocking.jl?branch=master)

Allows Julia functions to be temporarily modified for testing purposes.


## Usage

Using the `mend` function provides a way to temporarily overwrite a specific method. The original implementation of a method can be used within the replacement method by accessing it from the `Original` module.

```julia
julia> using Mocking

julia> open("foo")
ERROR: SystemError: opening file foo: No such file or directory
 in open at ./iostream.jl:90
 in open at iostream.jl:99

julia> replacement = (name::AbstractString) -> name == "foo" ? IOBuffer("bar") : Original.open(name)
(anonymous function)

replacement = (name::AbstractString) -> name == "foo" ? IOBuffer("bar") : Original.open(name)
julia> mend(Base.open, replacement) do
           readall(open("foo"))
       end
"bar"

julia> open("foo")  # Ensure original open behaviour is restored
ERROR: SystemError: opening file foo: No such file or directory
 in open at ./iostream.jl:90
 in open at iostream.jl:99
```

## Issues with inlining

When Julia compiles a function it may decide to inline the function call which you may want to mend:
```julia
julia> using Mocking

julia> myfunc() = open("foo")  # Will be replaced with `open(fname::AbstractString, rd::Bool, wr::Bool, cr::Bool, tr::Bool, ff::Bool)`
myfunc (generic function with 1 method)

julia> Base.precompile(myfunc, ())

julia> replacement = (name::AbstractString) -> name == "foo" ? IOBuffer("bar") : Original.open(name)
(anonymous function)

julia> mend(Base.open, replacement) do
           readall(myfunc())
       end
ERROR: SystemError: opening file foo: No such file or directory
 in open at ./iostream.jl:90
 in myfunc at none:1
```

To stop Julia from inlining a particular call you can wrap the arguments with `[args; kwargs]...` to ensure that the call can be mended:
```julia
julia> using Mocking

julia> myfunc() = open(["foo"]...)
myfunc (generic function with 1 method)

julia> Base.precompile(myfunc, ())

julia> replacement = (name::AbstractString) -> name == "foo" ? IOBuffer("bar") : Original.open(name)
(anonymous function)

julia> mend(Base.open, replacement) do
           readall(myfunc())
       end
"bar"
```
