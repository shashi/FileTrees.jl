export load, mapvalues, save, NoValue

function load(f, t::DirTree; dirs=false)
    inner = DirTree(t; children=map(c->load(f, c; dirs=dirs), children(t)))
    dirs ? DirTree(inner, value=f(inner)) : inner
end

load(f, t::File; dirs=false) = File(t, value=f(t))

mapvalues(f, x::File) = hasvalue(x) ? File(x, value=f(value(x))) : x

function mapvalues(f, t::DirTree)
    x = DirTree(t, children = mapvalues.(f, t.children))
    hasvalue(x) ? DirTree(x, value=f(value(x))) : x
end

function mapreducevals(g, f, t::DirTree; associative=true)
    x = mapreducevals.(g, f, t.children)
    associative ? assocreduce(g, x) : reduce(g, x)
end

function reducevalues(f, t::DirTree; associative=true, across_dirs=false)
    if associative && across_dirs
    end
end

function save(f, t::DirTree)
    mkpath(path(t))
    foreach(x->save(f, x), children(t))
end

save(f, t::File) = hasvalue(t) && f(t)

