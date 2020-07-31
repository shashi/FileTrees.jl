export load, mapvalues, reducevalues, save, NoValue, hasvalue

"""
apply `f` to any node that has a value. `f` gets the node itself
and must return a node.
"""
mapvalued(f, t::Node; walk=postwalk) = walk(x->hasvalue(x) ? x <| f : x, t)

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
function load(f, t::Node; dirs=false, walk=postwalk)
    walk(t) do x
        !dirs && x isa DirTree && return x
        typeof(x)(value=f <| x)
    end
end

"""
    mapvalues(f, x::DirTree)

(See `load` to load values into nodes of a tree.)

Apply `f` to the value of all nodes in `x` which have a value.
Returns a new tree where every value is replaced with the result of applying `f`.

`f` may return `NoValue()` to cause no value to be associated with a node.
"""
mapvalues(f, t::Node) = mapvalued(x -> typeof(x)(value=f(value(x))), t)

"""
    reducevalues(f, t::DirTree; associative=true)

Use `f` to combine values in the tree.

- `associative=true` assumes `f` can be applied in an associative way
"""
function reducevalues(f, t::DirTree; associative=true)
    itr = value.(collect(Iterators.filter(hasvalue, Leaves(t))))
    associative ? assocreduce(<|(f), itr) : reduce(<|(f), itr)
end

"""
    save(f, x::Node)

Save a DirTree to disk. Creates the directory structure
and calls `f` with `File` for every file in the tree which
has a value associated with it.

(see `load` and `mapvalues` for associating values with files.)
"""
save(f, t::Node) = mapvalued(x->(mkpath(dirname(f)); f(x)), t)
