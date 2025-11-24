const MAX_WORLD_AGE = typemax(UInt64)

function delete_method(m::Method)
    @static if VERSION >= v"1.12.0"
        # On Julia 1.12 deleting a method re-activates the previous version of method
        Base.delete_method(m)
    else
        # The method table associated with the generic function
        mt = Base.get_methodtable(m)

        world_age = Base.get_world_counter()
        current_method = nothing
        old_method = nothing

        # The `Core.MethodTable` stores each method as a linked list with the newest method
        # definitions occurring first.
        def = mt.defs
        while !isnothing(def)
            if def.sig == m.sig
                if def.max_world == MAX_WORLD_AGE
                    current_method = def.func
                else
                    old_method = def.func
                    break
                end
            end
            def = def.next
        end

        # When the method table contains 2+ methods for the signature we'll restore the previous
        # method definition. Otherwise, we'll just limit the world age for the only existing
        # method.
        if !isnothing(old_method)
            # Using `primary_world == 1` causes Julia to increase the world counter
            replacement_method = deepcopy(old_method)
            replacement_method.primary_world = 1
            replacement_method.deleted_world = MAX_WORLD_AGE

            ccall(:jl_method_table_insert, Cvoid, (Any, Any, Any), mt, replacement_method, replacement_method.sig)
        else
            # On Julia versions below 1.12 just limits the world age specified method.
            Base.delete_method(m)
        end
    end

    return nothing
end
