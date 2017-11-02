# Test that Mocking works at various scopes

# Global scope
global_scope() = "foo"

# The @mock macro is essentially a no-op
@test (@mock global_scope()) == global_scope()

# Create a patched version of func() and return the alternative
# version at call sites using the @mock macro
global_patch = (@patch global_scope() = "bar")
apply(global_patch) do
    @test (@mock global_scope()) != global_scope()
end

# The @mock macro should return to the original behaviour
@test (@mock global_scope()) == global_scope()

# Local scope within a function
function scope_test()
    function_scope() = "foo"
    @test (@mock function_scope()) == function_scope()

    patch = @patch function_scope() = "bar"
    apply(patch) do
        @test (@mock function_scope()) != function_scope()
    end

    @test (@mock function_scope()) == function_scope()
end
scope_test()

# Local scope within a let-block
let let_scope
    let_scope() = "foo"
    @test (@mock let_scope()) == let_scope()

    patch = @patch let_scope() = "bar"
    apply(patch) do
        @test (@mock let_scope()) != let_scope()
    end

    @test (@mock let_scope()) == let_scope()
end
