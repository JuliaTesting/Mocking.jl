# Note: generated functions appear not be optimized
macro mendable(expr)
    esc(:((@generated $(gensym())() = $expr)()))
end
