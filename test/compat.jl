get_methodtable(m::Method) = Base.get_methodtable(m)
get_methodtable(f::Function) = get_methodtable(first(methods(f)))

function show_methodtable(io::IO, mt)
    def = mt.defs
    println("---")
    while Base.MethodList(mt)
        Base.show_method(io, def.func)
        println(io, "\n    World Age: ", repr(def.min_world), " - ", repr(def.max_world))
    end
end

function show_methodtable(io::IO, m::Method)
    println("---")
    for el in Base.MethodList(get_methodtable(m))
        el.sig == m.sig || continue
        show(io, el)
        println(io, "\n    World Age: ", repr(el.primary_world))
        # , " - ", repr(el.deleted_world))
    end
end

show_methodtable(io::IO, f::Function) = show_methodtable(io, first(methods(f)))
show_methodtable(x) = show_methodtable(stdout, x)

@testset "delete_method" begin
    @testset "delete and restore" begin
        foo(::Int) = :original
        original_world_age = Mocking.get_world_counter()

        foo(::Int) = :replaced
        replaced_world_age = Mocking.get_world_counter()

        @test foo(1) === :replaced
        @test length(methods(foo)) == 1
        @test original_world_age < replaced_world_age

        m = first(methods(foo, Tuple{Int}))
        @test Mocking.delete_method(m) === nothing
        deleted_world_age = Mocking.get_world_counter()

        @test foo(1) === :original
        @test length(methods(foo)) == 1
        @test replaced_world_age < deleted_world_age

        @test Base.invoke_in_world(original_world_age, foo, 1) === :original
        @test Base.invoke_in_world(replaced_world_age, foo, 1) === :replaced
        @test Base.invoke_in_world(deleted_world_age, foo, 1) === :original

        @static if VERSION < v"1.12"
            mt = get_methodtable(m)
            def = mt.defs
            count = 0
            while def !== nothing
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
    end

    @testset "delete only" begin
        foo(::Int) = :original
        original_world_age = Mocking.get_world_counter()

        @test foo(1) === :original
        @test length(methods(foo)) == 1

        m = first(methods(foo, Tuple{Int}))
        @test Mocking.delete_method(m) === nothing
        deleted_world_age = Mocking.get_world_counter()

        @test_throws MethodError foo(1)
        @test length(methods(foo)) == 0
        @test original_world_age < deleted_world_age

        @test Base.invoke_in_world(original_world_age, foo, 1) === :original
        @test_throws MethodError Base.invoke_in_world(deleted_world_age, foo, 1)

        @static if VERSION < v"1.12"
            mt = get_methodtable(m)
            def = mt.defs
            count = 0
            while def !== nothing
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
end
