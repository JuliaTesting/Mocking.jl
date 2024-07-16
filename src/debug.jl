function _intercepted_msg(
    call_site::AbstractString, method::Union{Method,Nothing}, reason::AbstractString
)
    return """
        Mocking intercepted:
        call site:  $call_site
        dispatched: $(method === nothing ? "(no matching method)" : method)
        reason:     $reason
        """
end

function _call_site(target, args, location)
    call = "$target($(join(map(arg -> "::$(Core.Typeof(arg))", args), ", ")))"
    return "$call $location"
end

# Mirroring the print format used when showing a method. Based upon the function
# `Base.print_module_path_file` which was introduced in Julia 1.10.
if VERSION >= v"1.9"
    function _print_module_path_file(io::IO, modul, file::AbstractString, line::Integer)
        print(io, "@")

        # module
        modul !== nothing && print(io, " ", modul)

        # filename, separator, line
        file = contractuser(file)
        print(io, " ", file, ":", line)
    end
else
    function _print_module_path_file(io::IO, modul, file::AbstractString, line::Integer)
        print(io, "in")

        # module
        modul !== nothing && print(io, " ", modul, " at")

        # filename, separator, line
        print(io, " ", file, ":", line)
    end
end

function _print_module_path_file(io::IO, modul, source::LineNumberNode)
    return _print_module_path_file(io, modul, string(source.file), source.line)
end
