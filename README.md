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

### @mendable

Some functions you want to mock are called from the function you are testing. If the function you are testing is compiled, you will not be able to mock the internal function. That is where `@mendable` can help, it will allow you to mock the internal functions to your needs. As show in this example.

```julia
julia> function_inside() = println("a")
function_inside (generic function with 1 method)

julia> test1() = function_inside()
test1 (generic function with 1 method)

julia> test2() = @mendable function_inside()
test2 (generic function with 1 method)

julia> test1()
a

julia> test2()
a

julia> function_inside() = println("b")
function_inside (generic function with 1 method)

julia> test1()
a

julia> test2()
b
```

### Patch

`Patch` allows similar behaviour as you would get from using `mend` directly. Note that you only need to specify a signature when the function you are overloading has multiple methods and the replacement would be ambiguous.

```julia
julia> replacement = (name::AbstractString) -> name == "foo" ? IOBuffer("bar") : Original.open(name)
(anonymous function)

julia> mend(Patch(open, replacement)) do
           readall(open("foo"))
       end
"bar"
```

We can also define multiple patches to make the code more readable.

```julia
julia> demo(filename) = @mendable isfile(filename) && readall(open(filename)) # this is just so we can show both calls are being used
demo (generic function with 1 method)

julia> new_isfile(f::AbstractString) = f == "foo" ? true : Original.isfile(f)
new_isfile (generic function with 1 method)

julia> new_open = (f::AbstractString) -> f == "foo" ? IOBuffer("bar") : Original.open(f)
(anonymous function)

julia> patch_isfile = Patch(isfile, new_isfile)
Mocking.Patch(isfile,(anonymous function),Mocking.Signature(Type[AbstractString]))

julia> patch_open = Patch(open, new_open)
Mocking.Patch(open,(anonymous function),Mocking.Signature(Type[AbstractString]))

julia> mend(patch_isfile, patch_open) do
           demo("foo")
       end
"bar"

julia> patches = [patch_isfile, patch_open]
2-element Array{Mocking.Patch,1}:
 Mocking.Patch(isfile,(anonymous function),Mocking.Signature(Type[AbstractString]))
 Mocking.Patch(open,(anonymous function),Mocking.Signature(Type[AbstractString]))

julia> mend(patches) do
           demo("foo")
       end
"bar"
```

## Compiler Issues

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

To stop Julia from inlining a particular call you can wrap the function call with `@mendable` to ensure that the call can be mended:
```julia
julia> using Mocking

julia> myfunc() = @mendable open("foo")
myfunc (generic function with 1 method)

julia> Base.precompile(myfunc, ())

julia> replacement = (name::AbstractString) -> name == "foo" ? IOBuffer("bar") : Original.open(name)
(anonymous function)

julia> mend(Base.open, replacement) do
           readall(myfunc())
       end
"bar"
```
