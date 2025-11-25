# To validate `delete_method` we need to check the world age range associated with a method.
# In Julia 1.11 and below we could use `Base.get_methodtable` to view all of the current and
# outdated methods associated with the generic function. In Julia 1.12 this function now
# returns a method table for all generic functions. The `get_methodtableentry` function is
# an attempt to provide a common interface between various versions of Julia.
if VERSION >= v"1.12"
    function get_methodtableentry(m::Method)
        mt = Base.get_methodtable(m)
        func = Base.unwrap_unionall(m.sig).types[1]
        return mt.defs !== nothing ? _get_methodtableentry(mt.defs, func) : nothing
    end

    # Adapted from the `Base.visit` function:
    # https://github.com/JuliaLang/julia/blob/a4d2b6a358aeaa9814c37c0644fe3c56f3d90823/base/runtime_internals.jl#L1806-L1842
    function _get_methodtableentry(mc::Core.TypeMapLevel, ft::Type)
        function avisit(e::Memory{Any})
            for i in 2:2:length(e)
                isassigned(e, i) || continue
                ei = e[i]
                if ei isa Memory{Any}
                    for j in 2:2:length(ei)
                        isassigned(ei, j) || continue
                        mte = _get_methodtableentry(ei[j], ft)
                        mte === nothing || return mte
                    end
                else
                    mte = _get_methodtableentry(ei, ft)
                    mte === nothing || return mte
                end
            end
            return nothing
        end
        if mc.targ !== nothing
            mte = avisit(mc.targ::Memory{Any})
            mte === nothing || return mte
        end
        if mc.arg1 !== nothing
            mte = avisit(mc.arg1::Memory{Any})
            mte === nothing || return mte
        end
        if mc.tname !== nothing
            mte = avisit(mc.tname::Memory{Any})
            mte === nothing || return mte
        end
        if mc.name1 !== nothing
            mte = avisit(mc.name1::Memory{Any})
            mte === nothing || return mte
        end
        if mc.list !== nothing
            mte = _get_methodtableentry(mc.list, ft)
            mte === nothing || return mte
        end
        if mc.any !== nothing
            mte = _get_methodtableentry(mc.any, ft)
            mte === nothing || return mte
        end
        return nothing
    end

    function _get_methodtableentry(d::Core.TypeMapEntry, ft::Type)
        while d !== nothing
            Base.unwrap_unionall(d.func.sig).types[1] == ft && return d
            d = d.next
        end
    end
else
    function get_methodtableentry(m::Method)
        mt = Base.get_methodtable(m)
        return mt.defs !== nothing ? mt.defs : nothing
    end
end

function get_methodlist(m::Method)
    mt = Base.get_methodtable(m)
    ml = Base.MethodList(mt)
    return if VERSION >= v"1.12"
        func_type = Base.unwrap_unionall(m.sig).types[1]
        filter(el -> Base.unwrap_unionall(el.sig).types[1] == func_type, ml)
    else
        collect(ml)
    end
end

function show_methodtableentry(io::IO, def)
    println("---")
    while !isnothing(def)
        Base.show_method(io, def.func)
        print(io, "\n    World Age: ")
        println(io, repr(def.min_world), " - ", repr(def.max_world))
        def = def.next
    end
    return nothing
end

function show_methodtableentry(io::IO, m::Method)
    return show_methodtableentry(io, get_methodtableentry(m))
end

show_methodtableentry(x) = show_methodtableentry(stdout, x)

@testset "delete_method" begin
    @testset "delete and restore" begin
        foo(::Int) = :original
        original_world_age = Base.get_world_counter()
        original_method = first(methods(foo))

        # @show original_world_age
        # show_methodtableentry(original_method)

        foo(::Int) = :replaced
        replaced_world_age = Base.get_world_counter()
        replaced_method = first(methods(foo))

        # @show replaced_world_age
        # show_methodtableentry(original_method)

        @test foo(1) === :replaced
        @test length(methods(foo)) == 1
        @test original_world_age < replaced_world_age

        @test Mocking.delete_method(replaced_method) === nothing
        deleted_world_age = Base.get_world_counter()

        # @show deleted_world_age
        # show_methodtableentry(original_method)

        @test foo(1) === :original
        @test length(methods(foo)) == 1
        @test replaced_world_age < deleted_world_age

        @test Base.invoke_in_world(original_world_age, foo, 1) === :original
        @test Base.invoke_in_world(replaced_world_age, foo, 1) === :replaced
        @test Base.invoke_in_world(deleted_world_age, foo, 1) === :original

        # Validate the world age range associated with the methods
        def = get_methodtableentry(original_method)
        expected_count = VERSION >= v"1.12" ? 2 : 3
        count = 0
        while def !== nothing
            count += 1

            if VERSION >= v"1.12"
                if count == 1
                    @test def.min_world == replaced_world_age
                    @test def.max_world == replaced_world_age
                elseif count == 2
                    @test def.min_world == original_world_age
                    @test def.max_world == typemax(UInt)
                end
            else
                if count == 1
                    @test def.min_world == deleted_world_age
                    @test def.max_world == typemax(UInt)
                elseif count == 2
                    @test def.min_world == replaced_world_age
                    @test def.max_world == replaced_world_age
                elseif count == 3
                    @test def.min_world == original_world_age
                    @test def.max_world == original_world_age
                end
            end

            def = def.next
        end
        @test count == expected_count

        ml = get_methodlist(original_method)
        @test length(ml) == expected_count
        if VERSION >= v"1.12"
            @test ml[1].primary_world == replaced_world_age
            @test ml[2].primary_world == original_world_age
        else
            @test ml[1].primary_world == deleted_world_age
            @test ml[1].deleted_world == typemax(UInt)
            @test ml[2].primary_world == replaced_world_age
            @test ml[2].deleted_world == replaced_world_age
            @test_broken ml[3].primary_world == original_world_age
            @test_broken ml[3].deleted_world == original_world_age
        end
    end

    @testset "delete only" begin
        foo(::Int) = :original
        original_world_age = Base.get_world_counter()
        original_method = first(methods(foo))

        @test foo(1) === :original
        @test length(methods(foo)) == 1

        @test Mocking.delete_method(original_method) === nothing
        deleted_world_age = Base.get_world_counter()

        @test_throws MethodError foo(1)
        @test length(methods(foo)) == 0
        @test original_world_age < deleted_world_age

        @test Base.invoke_in_world(original_world_age, foo, 1) === :original
        @test_throws MethodError Base.invoke_in_world(deleted_world_age, foo, 1)

        # Validate the world age range associated with the methods
        def = get_methodtableentry(original_method)
        count = 0
        while def !== nothing
            count += 1

            if count == 1
                @test def.min_world == original_world_age
                @test def.max_world == original_world_age
            end

            def = def.next
        end
        @test count == 1

        ml = get_methodlist(original_method)
        @test length(ml) == 1
        if VERSION >= v"1.12"
            @test ml[1].primary_world == original_world_age
        else
            @test ml[1].primary_world == original_world_age
            @test ml[1].deleted_world == original_world_age
        end
    end

    @testset "delete non-latest" begin
        foo(::Int) = :original
        original_world_age = Base.get_world_counter()
        original_method = first(methods(foo))

        foo(::Int) = :replaced
        replaced_world_age = Base.get_world_counter()
        replaced_method = first(methods(foo))

        @test original_method != replaced_method

        @test foo(1) === :replaced
        @test length(methods(foo)) == 1
        @test original_world_age < replaced_world_age

        @test Mocking.delete_method(original_method) === nothing
        deleted_world_age = Base.get_world_counter()

        @test foo(1) === :replaced
        @test length(methods(foo)) == 1
        @test replaced_world_age < deleted_world_age

        @test Base.invoke_in_world(original_world_age, foo, 1) === :original
        @test Base.invoke_in_world(replaced_world_age, foo, 1) === :replaced
        @test Base.invoke_in_world(deleted_world_age, foo, 1) === :replaced

        def = get_methodtableentry(original_method)
        count = 0
        while def !== nothing
            count += 1

            if count == 1
                @test def.min_world == replaced_world_age
                @test def.max_world == typemax(UInt)
            elseif count == 2
                @test def.min_world == original_world_age
                @test def.max_world == replaced_world_age
            end

            def = def.next
        end
        @test count == 2

        ml = get_methodlist(original_method)
        @test length(ml) == 2
        if VERSION >= v"1.12"
            @test ml[1].primary_world == replaced_world_age
            @test ml[2].primary_world == original_world_age
        else
            @test ml[1].primary_world == replaced_world_age
            @test ml[1].deleted_world == typemax(UInt)
            @test ml[2].primary_world == original_world_age
            @test ml[2].deleted_world == replaced_world_age
        end
    end

    @testset "signature specific" begin
        foo(::Int) = :original
        original_world_age = Base.get_world_counter()
        foo(::Float64) = :original
        float_world_age = Base.get_world_counter()
        original_method = first(methods(foo, Tuple{Int}))

        # @show original_world_age
        # show_methodtableentry(original_method)

        foo(::Int) = :replaced
        replaced_world_age = Base.get_world_counter()
        replaced_method = first(methods(foo, Tuple{Int}))

        # @show replaced_world_age
        # show_methodtableentry(original_method)

        @test original_method != replaced_method

        @test foo(1) === :replaced
        @test foo(1.0) === :original
        @test length(methods(foo)) == 2
        @test original_world_age < replaced_world_age

        @test Mocking.delete_method(replaced_method) === nothing
        deleted_world_age = Base.get_world_counter()

        # @show deleted_world_age
        # show_methodtableentry(original_method)

        @test foo(1) === :original
        @test foo(1.0) === :original
        @test length(methods(foo)) == 2
        @test replaced_world_age < deleted_world_age

        @test Base.invoke_in_world(original_world_age, foo, 1) === :original
        @test Base.invoke_in_world(replaced_world_age, foo, 1) === :replaced
        @test Base.invoke_in_world(deleted_world_age, foo, 1) === :original

        # Validate the world age range associated with the methods
        def = get_methodtableentry(original_method)
        count = 0
        while def !== nothing
            count += 1

            if VERSION >= v"1.12"
                if count == 1
                    @test def.sig == Tuple{typeof(foo), Int}
                    @test def.min_world == replaced_world_age
                    @test def.max_world == replaced_world_age
                elseif count == 2
                    @test def.sig == Tuple{typeof(foo), Float64}
                    @test def.min_world == float_world_age
                    @test def.max_world == typemax(UInt)
                elseif count == 3
                    @test def.sig == Tuple{typeof(foo), Int}
                    @test def.min_world == original_world_age
                    @test def.max_world == typemax(UInt)
                end
            else
                if count == 1
                    @test def.sig == Tuple{typeof(foo), Int}
                    @test def.min_world == deleted_world_age
                    @test def.max_world == typemax(UInt)
                elseif count == 2
                    @test def.sig == Tuple{typeof(foo), Int}
                    @test def.min_world == replaced_world_age
                    @test def.max_world == replaced_world_age
                elseif count == 3
                    @test def.sig == Tuple{typeof(foo), Float64}
                    @test def.min_world == float_world_age
                    @test def.max_world == typemax(UInt)
                elseif count == 4
                    @test def.sig == Tuple{typeof(foo), Int}
                    @test def.min_world == original_world_age
                    @test def.max_world == float_world_age
                end
            end

            def = def.next
        end
        @test count == (VERSION >= v"1.12" ? 3 : 4)

        ml = get_methodlist(original_method)
        @test length(ml) == (VERSION >= v"1.12" ? 3 : 4)
        if VERSION >= v"1.12"
            @test ml[1].sig == Tuple{typeof(foo), Int}
            @test ml[1].primary_world == replaced_world_age

            @test ml[2].sig == Tuple{typeof(foo), Float64}
            @test ml[2].primary_world == float_world_age

            @test ml[3].sig == Tuple{typeof(foo), Int}
            @test ml[3].primary_world == original_world_age
        else
            @test ml[1].sig == Tuple{typeof(foo), Int}
            @test ml[1].primary_world == deleted_world_age
            @test ml[1].deleted_world == typemax(UInt)

            @test ml[2].sig == Tuple{typeof(foo), Int}
            @test ml[2].primary_world == replaced_world_age
            @test ml[2].deleted_world == replaced_world_age

            @test ml[3].sig == Tuple{typeof(foo), Float64}
            @test ml[3].primary_world == float_world_age
            @test ml[3].deleted_world == typemax(UInt)

            @test ml[4].sig == Tuple{typeof(foo), Int}
            @test_broken ml[4].primary_world == original_world_age
            @test_broken ml[4].deleted_world == float_world_age
        end
    end
end
