using Mocking

# Global scope
global_scope() = "foo"

patch = @patch global_scope() = "bar"
pe = Mocking.PatchEnv(patch)
Mocking.set_active_env(pe)

@test global_scope() == "foo"
@test (@mock global_scope()) == "bar"

# Local scope within a function
function scope_test()
    function_scope() = "foo"

    patch = @patch function_scope() = "bar"
    pe = Mocking.PatchEnv(patch)
    Mocking.set_active_env(pe)

    @test function_scope() == "foo"
    @test (@mock function_scope()) == "bar"
end
scope_test()

# Local scope within a let-block
let let_scope
    let_scope() = "foo"

    patch = @patch let_scope() = "bar"
    pe = Mocking.PatchEnv(patch)
    Mocking.set_active_env(pe)

    @test let_scope() == "foo"
    @test (@mock let_scope()) == "bar"
end
