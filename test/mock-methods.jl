foo(arr::AbstractArray{Float64}) = map(foo, arr)  # Typically foo should use @mock here
foo(x::Float64) = floor(x)

@testset "mock some methods but not others" begin
    @test foo(1.6) == 1.0
    @test foo([1.6]) == [1.0]


    # Patching only the function that takes a scalar
    apply(@patch foo(x::Float64) = ceil(x)) do
        @test foo(1.6) == 2.0
        @test foo([1.6]) == [2.0]  # Ends up calling patched function
    end

    # Patching both methods, so inner method is not called by outer
    
    
    apply([
        @patch(foo(x::Float64) = ceil(x)),
        @patch(foo(arr::AbstractArray{Float64}) = -1 .* arr),
        ]) do

        @test foo(1.6) == 2.0
        @test foo([1.6]) == [-1.6]
    end
end


