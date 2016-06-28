# Testcase from example given in Mocking.jl's README

import Compat: read, unsafe_string

function randdev(n::Integer)
    @mock open("/dev/urandom") do fp
        reverse(read(fp, n))
    end
end

result = randdev(10)
@test eltype(result) == UInt8
@test length(result) == 10

data = unsafe_string(pointer(convert(Array{UInt8}, 1:10)))  # Produces exactly 10 values

# Generate a alternative method of the `open` call we wish to mock.
patch = @patch open(fn::Function, f::AbstractString) = fn(IOBuffer(data))

# Apply the patch which will modify the behaviour for our test.
apply(patch) do
    @test randdev(10) == convert(Array{UInt8}, 10:-1:1)
end
