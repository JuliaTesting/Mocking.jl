import Base: @deprecate_binding, @deprecate

macro mock(expr)
    @warn "@mock is deprecated to nothing. It is no longer required." maxlog=1
    return esc(expr)
end

function enable(;force::Bool=false)
    @warn "enable is deprecated to nothing. It is no longer required." maxlog=1
    return
end
