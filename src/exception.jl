import Base: showerror

type FunctionError <: Exception
    mod::Symbol
    name::Symbol
end

FunctionError(mod::Module, name::Symbol) = FunctionError(module_name(mod), name)

showerror(io::IO, ex::FunctionError) = print(io, "FunctionError: function $(ex.name) does not exist in module $(ex.mod)")
