import Mocking: FunctionError

buffer = IOBuffer()
showerror(buffer, FunctionError(Base, :foo))
@test takebuf_string(buffer) == "FunctionError: function foo does not exist in module Base"
