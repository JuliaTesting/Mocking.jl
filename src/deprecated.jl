
macro mock(expr)
    w = Expr(
        :macrocall,
        Symbol("@warn"),
        __source__,
        "`@mock` is no longer used and can be removed.",
    )
   quote
       $w
       $(esc(expr))
   end
end

function enable(;force::Bool=false)
    Base.depwarn("`Mocking.enable` is no longer used and can be removed.", :enable)
end
