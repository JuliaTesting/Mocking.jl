
let generic() = "foo"
    Patch.override(generic, () -> "bar")
    @test generic() == "bar"
end

let anonymous = () -> "foo"
    Patch.override(anonymous, () -> "bar")
    @test anonymous() == "bar"
end

let generic(name) = name
    Patch.backup(generic, Tuple{Any})
    Patch.override(generic, (name) -> name == "bar" ? "baz" : Original.generic(name))
    @test generic("bar") == "baz"
    @test generic("foo") == "foo"
end

let open = Base.open
    replacement = (name::AbstractString) -> name == "bar" ? "baz" : Original.open(name)
    Patch.backup(open, Patch.signature(replacement))
    Patch.override(open, replacement)
    @test open("bar") == "baz"
    @test isa(open(tempdir()), IOStream)
end
