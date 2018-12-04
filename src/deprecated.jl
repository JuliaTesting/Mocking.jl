import Base: @deprecate_binding, @deprecate

macro mock(expr)
    quote
        @warn "@mock is deprecated to nothing. It is no longer required." maxlog=1
        $expr
    end |> esc
end

function enable(;force::Bool=false)
    esc(:(@warn "enable is deprecated to nothing. It is no longer required." maxlog=1))
end
