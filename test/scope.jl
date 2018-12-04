# Test that can mock things at various scopes

module DemoOuter
    module DemoInner
        inner() = "O I i"
    end
    
    outer() = "O o"
end

### Without importing

demo_outer() = identity(DemoOuter.outer())
using .DemoOuter: outer
@testset "Module outer" begin
    @testset "Fully qualified name" begin
        apply(@patch DemoOuter.outer() = "patched") do
            @test demo_outer() == "patched"
        end
    end

   @testset "Unqualified name" begin
        apply(@patch outer() = "patched2") do
            @test demo_outer() == "patched2"
        end
    end
end

demo_inner() = identity(DemoOuter.DemoInner.inner())
using .DemoOuter.DemoInner: inner
@testset "Inner module" begin
    @testset "Fully qualified name" begin
        apply(@patch DemoOuter.DemoInner.inner() = "patched") do
            @test demo_inner() == "patched"
        end
    end

    @testset "Unqualified name" begin
        apply(@patch inner() = "patched2") do
            @test demo_inner() == "patched2"
        end
    end
end
