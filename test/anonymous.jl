# Mocking uses makes of anonymous functions for patches. Mocking cannot support optional
# or keyword parameters while these are unsupported with anonymous functions.

# Optional parameters are not allowed in anonymous functions
expr = :((x::Integer=0) -> x)
@test_throws ErrorException Core.eval(expr)

# Keyword parameters are not allowed in anonymous functions
expr = :((x; debug::Bool=false) -> debug)
@test_throws ErrorException Core.eval(expr)
