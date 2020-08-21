lazify(flag::Nothing, f) = maybe_lazy(f)
lazify(flag::Bool, f) = flag ? lazy(f) : f

maybe_apply(f, x::NoValue) = NoValue()
maybe_apply(f, x) = f(x)
# maybe_apply(f, xs...) = all(x->x isa NoValue, xs) ? NoValue() : f(xs...)
# maybe needed later ^
maybe(f) = (xs...)->maybe_apply(f, xs...)

"""
apply `f` to any node that has a value. `f` gets the node itself
and must return a node.
"""
function mapvalued(f, t::Node; walk=postwalk)
    walk(x->hasvalue(x) ? f(x) : x, t)
end

"""
    load(f, t::FileTree; dirs=false)

Walk the tree and optionally load data for nodes in it.

`f(file)` is the loader function which takes `File` as input.
Call `path(file)` to get the String path to read the  file.

If `dirs = true` then `f` can either get a `File` or `FileTree`.
nodes within `FileTree` will have already been loaded.

If `NoValue()` is returned by `f`, no value is attached to the node.
`hasvalue(x)` tells you if `x` already has a value or not.
"""
function load(f, t::Node; dirs=false, walk=postwalk, lazy=false)

    loader = x -> begin
        (!dirs && x isa FileTree) && return x
        f′ = lazify(lazy, f)
        setvalue(x, f′(x))
    end

    walk(loader, t)
end

"""
    mapvalues(f, x::FileTree)

(See `load` to load values into nodes of a tree.)

Apply `f` to the value of all nodes in `x` which have a value.
Returns a new tree where every value is replaced with the result of applying `f`.

`f` may return `NoValue()` to cause no value to be associated with a node.
"""
function mapvalues(f, t::Node; lazy=nothing, walk=postwalk)
    mapvalued(x -> setvalue(x, lazify(lazy, maybe(f))(x[])), t; walk=postwalk)
end

const no_init = [:_no_init]
"""
    reducevalues(f, t::FileTree; associative=true, init=nothing)

Use `f` to combine values in the tree.

- `associative=true` assumes `f` can be applied in an associative way
- `init` keyword argument will be returned if the file tree is empty.
  if `init` is not provided, reduce over an empty tree will cause an
  error to be thrown
"""
function reducevalues(f, t::FileTree;
                      associative=true,
                      lazy=nothing,
                      dirs=false,
                      init=no_init)
    f′ = lazify(lazy, f)
    itr = getindex.(collect(filter(hasvalue, nodes(t, dirs=dirs))))
    if associative
        assocreduce(f′, itr, init=init)
    elseif init !== no_init
        reduce(f′, itr, init=init)
    else
        reduce(f′, itr)
    end
end
reducevalues(f, t::File; associative=true, lazy=nothing) = t[]

"""
Associative reduce
"""
function assocreduce(f, xs; init=no_init)
    if length(xs) == 0
        if init === no_init
            throw(ArgumentError("Reducing over an empty collection. Pass `init=val` to return val."))
        end
        return init
    end
    length(xs) == 1 && return xs[1]
    l = length(xs)
    m = div(l, 2)
    f(assocreduce(f, xs[1:m]), assocreduce(f, xs[m+1:end]))
end

"""
    save(f, x::Node)

Save a FileTree to disk. Creates the directory structure
and calls `f` with `File` for every file in the tree which
has a value associated with it.

(see `load` and `mapvalues` for associating values with files.)
"""
function save(f, t::Node; lazy=nothing, exec=true)
    t′ = mapvalued(t) do x
        isempty(x) && return NoValue()

        function saver(file, val)
            d = string(dirname(file))
            # TODO: this does not work if `string` is not called
            if !isdir(d)
                mkpath(d)
            end
            # XXX: serialization pitfall!
            f(setvalue(file, val))
        end

        setvalue(x, lazify(lazy, saver)(x, x[]))
    end

    # placeholder task that waits and returns nothing
    (exec ? FileTrees.exec : identity)(reducevalues((x,y)->nothing, t′, init=nothing))
end
