import Compat: Sys, read, unsafe_string

# Testcase from example given in Mocking.jl's README
@testset "readme" begin
    # Note: Function only works in UNIX environments.
    function randdev(n::Integer)
        @mock open("/dev/urandom") do fp
            reverse(read(fp, n))
        end
    end

    n = 10
    if Sys.isunix()
        result = randdev(n)  # Reading /dev/urandom only works on UNIX environments
        @test eltype(result) == UInt8
        @test length(result) == n
    end

    # Produces a string with sequential UInt8 values from 1:n
    data = unsafe_string(pointer(convert(Array{UInt8}, 1:n)))

    # Generate a alternative method of `open` which call we wish to mock
    patch = @patch open(fn::Function, f::AbstractString) = fn(IOBuffer(data))

    # Apply the patch which will modify the behaviour for our test
    apply(patch) do
        @test randdev(n) == convert(Array{UInt8}, n:-1:1)
    end

    if Sys.isunix()
        # Outside of the scope of the patched environment `@mock` is essentially a no-op
        @test randdev(n) != convert(Array{UInt8}, n:-1:1)
    end
end
