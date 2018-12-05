
macro mock(expr)
    w = Expr(:macrocall, Symbol("@warn"), __source__, "@mock is no longer required.")
   quote
       $w
       $(esc(expr))
   end
end

function enable(;force::Bool=false)
    esc(:(@warn "Mocking.enable is no longer required." maxlog=1))
end
