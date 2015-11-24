function ignore_stderr(body::Function)
    # TODO: Need to figure out what to do on Windows...
    @windows_only return body()

    stderr = Base.STDERR
    null = open("/dev/null", "w")
    redirect_stderr(null)
    try
        return body()
    catch
        # Note: Catch runs prior to finally but errors seem to display fine
        rethrow()
    finally
        redirect_stderr(stderr)
    end
end

# Based upon Base.to_tuple_type(::ANY)
function to_array_type(t::ANY)
    if isa(t, Tuple) || isa(t, AbstractArray) || isa(t, SimpleVector)
        return Type[t...]
    else
        error("argument tuple type must contain only types")
    end
end
