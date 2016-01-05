import Mocking: ignore_stderr, to_array_type

# TODO: Still not a great test...
@unix_only begin
    open("/dev/null", "w") do null
        @test_throws ErrorException STDERR.name
        ignore_stderr() do
            warn("you should never see this!")
            @test null.name == STDERR.name
        end
        @test_throws ErrorException STDERR.name
    end
end

@test_throws ErrorException to_array_type(Any)

@test to_array_type(()) == Type[]
@test to_array_type([]) == Type[]
@test to_array_type((Any,)) == Type[Any]
@test to_array_type([Any]) == Type[Any]
