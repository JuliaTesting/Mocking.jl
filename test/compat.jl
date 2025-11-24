get_methodtable(m::Method) = Base.get_methodtable(m)
get_methodtable(f::Function) = get_methodtable(first(methods(f)))

function show_mt(mt)
    def = mt.defs
    println("---")
    while !isnothing(def)
        Base.show_method(stdout, def.func)
        println(stdout, "\n    World Age: ", sprint(show, def.min_world), " - ", sprint(show, def.max_world))
        def = def.next
    end
end

show_mt(m::Method) = show_mt(Base.get_methodtable(m))
show_mt(f::Function) = show_mt(first(methods(f)))

@testset "delete_method" begin
    @testset "delete and restore" begin
        foo(::Int) = :original
        original_world_age = Base.get_world_counter()

        foo(::Int) = :replaced
        replaced_world_age = Base.get_world_counter()

        @test length(methods(foo)) == 1
        @test length(get_methodtable(foo)) == 2
        @test original_world_age < replaced_world_age

        m = first(methods(foo, Tuple{Int}))
        @test Mocking.delete_method(m) === nothing
        deleted_world_age = Base.get_world_counter()

        mt = get_methodtable(foo)
        @test length(methods(foo)) == 1
        @test length(mt) == 3
        @test replaced_world_age < deleted_world_age

        @test Base.invoke_in_world(original_world_age, foo, 1) === :original
        @test Base.invoke_in_world(replaced_world_age, foo, 1) === :replaced
        @test Base.invoke_in_world(deleted_world_age, foo, 1) === :original

        def = mt.defs
        count = 0
        while !isnothing(def)
            count += 1

            if count == 1
                @test def.min_world == deleted_world_age
                @test def.max_world == typemax(UInt64)
            elseif count == 2
                @test def.min_world == replaced_world_age
                @test def.max_world == replaced_world_age
            elseif count == 3
                @test def.min_world == original_world_age
                @test def.max_world == original_world_age
            end

            def = def.next
        end

        ml = Base.MethodList(mt)
        @test ml[1].primary_world == deleted_world_age
        @test ml[1].deleted_world == typemax(UInt64)
        @test ml[2].primary_world == replaced_world_age
        @test ml[2].deleted_world == replaced_world_age
        @test_broken ml[3].primary_world == original_world_age
        @test_broken ml[3].deleted_world == original_world_age
    end

    @testset "delete only" begin
        foo(::Int) = :original
        original_world_age = Base.get_world_counter()

        @test length(methods(foo)) == 1
        @test length(get_methodtable(foo)) == 1

        m = first(methods(foo, Tuple{Int}))
        @test Mocking.delete_method(m) === nothing
        deleted_world_age = Base.get_world_counter()

        mt = get_methodtable(m)
        @test length(methods(foo)) == 0
        @test length(mt) == 1
        @test original_world_age < deleted_world_age

        @test Base.invoke_in_world(original_world_age, foo, 1) === :original
        @test_throws MethodError Base.invoke_in_world(deleted_world_age, foo, 1)

        def = mt.defs
        count = 0
        while !isnothing(def)
            count += 1

            if count == 1
                @test def.min_world == original_world_age
                @test def.max_world == original_world_age
            end

            def = def.next
        end

        ml = Base.MethodList(mt)
        @test ml[1].primary_world == original_world_age
        @test ml[1].deleted_world == original_world_age
    end
end

