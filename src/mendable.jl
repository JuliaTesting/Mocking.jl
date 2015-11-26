# Note: Wraps argments to calls in `[args]...`
macro mendable(expr)
    esc(mendable(expr))
end

function mendable(ex::Expr)
    for i in eachindex(ex.args)
        !isa(ex.args[i], Expr) && continue
        ex.args[i] = mendable(ex.args[i])
    end

    if ex.head == :call
        ex = :($(ex.args[1])([$(ex.args[2:end]...)]...))
    end

    return ex
end
