export load, mapvalues, save, NoValue, hasvalue

"""
    load(f, t::DirTree; dirs=false)

Walk the tree and optionally load data for nodes in it.

`f(file)` is the loader function which takes `File` as input.
Call `path(file)` to get the String path to read the  file.

If `dirs = true` then `f` can either get a `File` or `DirTree`.
nodes within `DirTree` will have already been loaded.

If `NoValue()` is returned by `f`, no value is attached to the node.
`hasvalue(x)` tells you if `x` already has a value or not.
"""
function load end
function load(f, t::DirTree; dirs=false)
    inner = DirTree(t; children=map(c->load(f, c; dirs=dirs), children(t)))
    dirs ? DirTree(inner, value=f(inner)) : inner
end

load(f, t::File; dirs=false) = File(t, value=f(t))

"""
    mapvalues(f, x::DirTree)

(See `load` to load values into nodes of a tree.)

Apply `f` to the value of all nodes in `x` which have a value.
Returns a new tree where every value is replaced with the result of applying `f`.

`f` may return `NoValue()` to cause no value to be associated with a node.
"""
function mapvalues end
mapvalues(f, x::File) = hasvalue(x) ? File(x, value=f(value(x))) : x

function mapvalues(f, t::DirTree)
    x = DirTree(t, children = mapvalues.(f, t.children))
    hasvalue(x) ? DirTree(x, value=f(value(x))) : x
end

function reducevalues(f, t::DirTree; associative=true, across_dirs=false)
    if associative
        assocreduce(f, [value(c) for c in t.children if hasvalue(c)])
    else
        reduce(f, [value(c) for c in t.children if hasvalue(c)])
    end
end

"""
    save(f, x::DirTree)

Save a DirTree to disk. Creates the directory structure
and calls `f` with `File` for every file in the tree which
has a value associated with it.

(see `load` and `mapvalues` for associating values with files.)
"""
function save end
function save(f, t::DirTree)
    mkpath(path(t))
    foreach(x->save(f, x), children(t))
end

save(f, t::File) = hasvalue(t) && f(t)

