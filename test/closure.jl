# Test that Mocking works
# with patches referencing functions at various scopes

global_scope() = "foo"
global_patchfun() = "bar"
@testset "Not a closure Global scope" begin
    # Check normaolly not mocked
    @test global_scope() == "foo"

    # Create a patched version of func() and return the alternative version
    global_patch = (@patch global_scope() = global_patchfun())
    apply(global_patch) do
        @test global_scope() == "bar"
    end

    # Outside the `apply` should return to the original behaviour
    @test global_scope() == "foo"
end


magic(x) = false
@testset "more complex closure" begin
    sentinel = gensym("sentinel")
    @test magic(sentinel) == false

    # Getting closers to work means having a function created in the current scope
    patch = @patch magic(x) = x == sentinel
    apply(patch) do
        @test magic(sentinel) == true
    end
end

function_scope() = "foo"
@testset "Local scope within a function" begin
    function scope_test()
        @test function_scope() == "foo"
        inner() = "bar"

        patch = @patch function_scope() = inner()
        apply(patch) do
            @test function_scope() == "bar"
        end

        @test function_scope() == "foo"
    end
    scope_test()
end


let_scope() = "foo"
@testset "Local scope within a let block" begin
    let
        @test let_scope() == "foo"
        inner() = "bar"

        patch = @patch let_scope() = inner()
        apply(patch) do
            @test let_scope() == "bar"
        end

        @test let_scope() == "foo"
    end
end

###################### Test modules

module FooBar
    nonexported() = "bar"
    exported() = "bling"
    export exported
end

using .FooBar

module_scope() = "foo"
@testset "Module scope" begin
    @testset "Not imported" begin
        @test module_scope() == "foo"

        patch = @patch module_scope() = FooBar.nonexported()
        apply(patch) do
            @test module_scope() == "bar"
        end

        @test module_scope() == "foo"
    end

    @testset "Imported" begin
        patch = @patch module_scope() = exported()
        apply(patch) do
            @test module_scope() == "bling"
        end

        @test module_scope() == "foo"
    end
end

############################
# Test for nested modules
module NM_ModA
   module NM_ModB
      abstract type NM_AbstractFoo end
      struct NM_Foo <: NM_AbstractFoo
          x::String
      end
   end # ModB

   NM_bar(f::NM_ModB.NM_AbstractFoo) = "default"
   NM_baz(f::NM_ModB.NM_AbstractFoo) = NM_bar(f)
end # ModA

import .NM_ModA
import .NM_ModA: NM_bar, NM_baz, NM_ModB

@testset "nested modules" begin
   p = @patch NM_bar(f::NM_ModB.NM_AbstractFoo) = "mock"
   Mocking.apply(p) do
      @test NM_baz(NM_ModB.NM_Foo("X")) == "mock"
      #@show @code_typed baz(ModB.Foo("X"))
   end
end
