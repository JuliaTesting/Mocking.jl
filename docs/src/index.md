# Mocking

Allows Julia function calls to be temporarily overloaded for the purpose of testing.

## `randdev` Example

Suppose you wrote the function `randdev` (UNIX only). How would you go about writing tests
for it?

```jldoctest randdev; output=false
function randdev(n::Integer)
    open("/dev/urandom") do fp
        reverse(read(fp, n))
    end
end

# output
randdev (generic function with 1 method)
```

The non-deterministic behaviour of this function makes it hard to test but we can write some
tests dealing with the deterministic properties of the function such as:

```jldoctest randdev; output=false
using Test
# using ...: randdev

n = 10
result = randdev(n)
@test eltype(result) == UInt8
@test length(result) == n

# output
Test Passed
```

How could we create a test that shows the output of the function is reversed? Mocking.jl
provides the `@mock` macro which allows package developers to temporarily overload a
specific calls in their package. In this example we will apply `@mock` to the `open` call
in `randdev`:

```jldoctest randdev_mock; output=false
using Mocking: @mock

function randdev(n::Integer)
    @mock open("/dev/urandom") do fp
        reverse(read(fp, n))
    end
end

# output
randdev (generic function with 1 method)
```

With the call site being marked as "mockable" we can now write a testcase which allows
us to demonstrate the reversing behaviour within the `randdev` function:

```jldoctest randdev_mock; output=false
using Mocking
using Test
# using ...: randdev

Mocking.activate()  # Need to call `activate` before executing `apply`

n = 10
result = randdev(n)
@test eltype(result) == UInt8
@test length(result) == n

# Produces a string with sequential UInt8 values from 1:n
data = unsafe_string(pointer(convert(Array{UInt8}, 1:n)))

# Generate an alternative method of `open` which call we wish to mock
patch = @patch open(fn::Function, f::AbstractString) = fn(IOBuffer(data))

# Apply the patch which will modify the behaviour for our test
apply(patch) do
    @test randdev(n) == convert(Array{UInt8}, n:-1:1)
end

# Outside of the scope of the patched environment `@mock` is essentially a no-op
@test randdev(n) != convert(Array{UInt8}, n:-1:1)

# output
Test Passed
```
