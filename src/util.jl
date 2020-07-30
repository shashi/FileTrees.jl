"""
Associative reduce
"""
function assocreduce(f, xs)
    length(xs) == 1 && return xs[1]
    l = length(xs)
    m = div(l, 2)
    f(assocreduce(f, xs[1:m]), assocreduce(f, xs[m+1:end]))
end
