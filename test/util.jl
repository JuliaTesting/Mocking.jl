import Mocking: ignore_stderr, to_array_type

# TODO: Not a great test...
@unix_only begin
    ignore_stderr() do
        warn("you should never see this!")
    end
end

@test_throws ErrorException to_array_type(Any)

@test to_array_type(()) == Type[]
@test to_array_type([]) == Type[]
@test to_array_type((Any,)) == Type[Any]
@test to_array_type([Any]) == Type[Any]
