const PathLike = Union{AbstractString, AbstractPath}


######################### utilities ##############################

# Apply the combine operation on the value of two Nodes
# sometimes it maybe lazy. If one of the inputs is lazy,
# a new Thunk is set as the value of the resulting node
function apply_combine(f, x, y)
    (!hasvalue(x) && !hasvalue(y)) && return y
    try
        setvalue(x, maybe_lazy(f)(x[], y[]))
    catch err
        !(err isa UndefMergeError) && rethrow(err)
        error("$(name(x)) clashed with an existing file name at path $(path(x)).\n" *
              "Pass `combine=f` to define how to combine them.")
    end
end

# attach a node file at `path`; use `combine` to overwrite.
function attach(t, path::PathLike, t′; combine=_merge_error)
    spath = Path(path).segments
    
    t1 = t′
    for parentname in Iterators.reverse(spath)
        t1 = FileTree(nothing, parentname, [t1])
    end
    t1 = setparent!(FileTree(nothing, name(t), [t1]))

    isempty(t) && return t1
    _merge(t, t1; combine=combine)
end

# rewrite `tree` according by performing string search and replace on every
# path use `combine` to overwrite multiple files which map to the same path
# Note, callers may assume the returned tree has no references to anything in
# input and is therefore safe to mutate (e.g. with setparent!) 
function regex_rewrite_tree(tree, from_path, to_path, combine; associative=false)
    newtree = maketree(name(tree)=>[])
    # Exclude the root from the matching because
    #   1) the public API where the pattern is relative to the root and 
    #   2) attach wants a path relative to the root
    rootoffset = length(canonical_path(tree))+2

    combinetree = OrderedDict{String, Vector}()
    for x in Leaves(tree)
        newpath = replace(@view(canonical_path(x)[rootoffset:end]), from_path => to_path)
        push!(get!(() -> [], combinetree, newpath), x[])    
    end


    buildcache = Dict{String, Node}("" => newtree)
    cfun = maybe_lazy(combine)
    if associative
    for (path, vals) in combinetree
            val = length(vals) > 1 ? assocreduce(cfun, vals) : vals[1]
            _append_tree!(buildcache, newtree, path, val)
        end
    else
        for (path, vals) in combinetree
            val = length(vals) > 1 ? reduce(cfun, vals) : vals[1]
            _append_tree!(buildcache, newtree, path, val)
        end
    end
    newtree
end

function _append_tree!(buildcache, root, path, val)
    parentpath, name = splitdir(path)
    child = File(nothing, name, val)
    while root !== child
        nextpath, parentname = splitdir(parentpath)
        parent = get!(buildcache, parentpath) do
            FileTree(nothing, parentname, Node[])
        end
        push!(parent.children, child)
        length(parent.children) == 1 || break # We have seen this node before
        child = parent
        parentpath = nextpath
    end
end


# getindex but return the rooted tree
function _getsubtree(x, path::PathLike)
    _getsubtree(x, GlobMatch(string(path)))
end
_getsubtree(x, path) = x[path]


"""
A wrapper around function `f` which causes overwriter
functions (`combine` option) to get the nodes themselves
rather than the value stored in them.

Note that if the nodes have lazy values, the values will be Thunks.
"""
struct OnNodes
    f
end

apply_combine(f::OnNodes, x, y) = f(x, y)

function _combine(cs, combine)
    seen = Dict()
    out = []
    for c in cs
        prev = get(seen, name(c), nothing)
        if prev !== nothing
            out[prev] = apply_combine(combine, out[prev], c)
        else
            push!(out, c)
            seen[name(c)] = length(out)
        end
    end
    out
end

# flatten folders named  "." into the parent directory.
function normdots(x::FileTree; combine=_merge_error)
    c2 = Iterators.flatmap(children(x)) do y
        z=normdots(y; combine=combine)
        name(z) == "." ? children(z) : [z]
    end |> collect
    FileTree(x; children=_combine(c2, combine)) |> setparent
end

normdots(x::File; kw...) = x


################################ rm ################################

"""
    diff(t1::FileTree, t2::FileTree)

For each node in `t2` remove a node in `t1` at the same path if it exists.
Returns the difference tree.
"""
Base.diff(t1::FileTree, t2::FileTree) = setparent(_diff(t1, t2))
    
function _diff(t1::FileTree, t2::FileTree)
    if name(t1) == name(t2)

        cs = sizehint!([], length(children(t1)))
        for x in children(t1)
            nomatch=true
            for y in children(t2)
                if name(x) === name(y)
                    nomatch = false
                    if y isa File
                        @assert x isa File
                    elseif x isa FileTree && y isa FileTree
                        d = _diff(x, y)
                        if !isempty(d)
                            push!(cs, d)
                        end
                    end
                end
            end
            if nomatch
                push!(cs, x)
            end
        end
        FileTree(t1; children=cs)
    else
        t1
    end
end

"""
    rm(t::FileTree, pattern::Union{Glob, String, AbstractPath, Regex})

remove nodes which match `pattern` from the file tree.
"""
rm(t::FileTree, path) = diff(t, _getsubtree(t, path))

################################ cp ################################

"""
    cp(t::FileTree,
       from_path::Regex,
       to_path::SubstitutionString; combine, associative=false)

copy nodes in the file tree whose path matches the `from_tree` regular expression pattern
by renaming it to `to_path` pattern. Any sub-pattern in `from_path` which is surrounded by
paranthesis will be read as a matched substring which can be accessed in the to_path
substitution pattern using \\1, \\2 etc. positional matches.

If a file overwrites an existing node after copy, `combine` will be called to combine
them together. By default `combine` will error.

Use `associative=true` if `combine` is associative to improve parallelism.

## Example:

```julia
julia> t = maketree("dir" => [string(j) => [string(i)=>["data.csv"] for i = 1:2] for j=1:2])
dir/
├─ 1/
│  ├─ 1/
│  │  └─ data.csv
│  └─ 2/
│     └─ data.csv
└─ 2/
   ├─ 1/
   │  └─ data.csv
   └─ 2/
      └─ data.csv

julia> cp(t, r"^([^/]*)/([^/]*)/data.csv\$", s"\1/\2.csv")
dir/
├─ 1/
│  ├─ 1/
│  │  └─ data.csv
│  ├─ 1.csv
│  ├─ 2/
│  │  └─ data.csv
│  └─ 2.csv
└─ 2/
   ├─ 1/
   │  └─ data.csv
   ├─ 1.csv
   ├─ 2/
   │  └─ data.csv
   └─ 2.csv
```
"""
function cp(t::FileTree, from_path::Regex, to_path::SubstitutionString; combine=_merge_error, associative=false)
    newtree = regex_rewrite_tree(t, from_path, to_path, combine; associative=associative)
    merge(t, newtree; combine=combine)
end

function _merge(t1::FileTree, t2::FileTree; combine=_merge_error, dotnorm=true)
    bigt = if name(t1) == name(t2)
        t2_merged = falses(length(children(t2)))
        cs = sizehint!(Node[], length(children(t1)) + length(children(t2)))
        for x in children(t1)
            nomatch=true
            for idx in eachindex(children(t2))
                y = t2[idx]
                if name(x) === name(y)
                    if y isa FileTree
                        push!(cs, _merge(x, y; combine=combine, dotnorm=false))
                    else
                        push!(cs, apply_combine(combine, x, y))
                    end
                    t2_merged[idx] = true
                    nomatch=false
                    break
                end
            end
            if nomatch
                push!(cs, x)
            end
        end
        @inbounds for i in eachindex(children(t2))
            if !t2_merged[i]
                push!(cs, children(t2)[i])
            end
        end
        FileTree(t1; children=cs)
    else
        FileTree(nothing, ".", [t1, t2], NoValue())
    end
    # dotnorm seems to mostly be for the old mv usecase where nodes targeted for deletion were renamed to ".".
    # It is however (maybe unintentioally) in the public API and might play a role in the outermost else clause
    # above
    dotnorm ? normdots(bigt; combine=combine) : bigt
end


################################ mv ################################

"""
    mv(t::FileTree,
       from_path::Regex,
       to_path::SubstitutionString; combine, associative=false)

move nodes in the file tree whose path matches the `from_tree` regular expression pattern
by renaming it to `to_path` pattern. Any sub-pattern in `from_path` which is surrounded by
paranthesis will be read as a matched substring which can be accessed in the to_path
substitution pattern using \\1, \\2 etc. positional matches.

If a file overwrites an existing node after copy, `combine` will be called to combine
them together. By default `combine` will error.

Use `associative=true` if `combine` is associative to improve parallelism.

## Example:

```julia
julia> t = maketree("dir" => [string(j) =>
                                [string(i)=>["data.csv"]
                                    for i = 1:2] for j=1:2])
dir/
├─ 1/
│  ├─ 1/
│  │  └─ data.csv
│  └─ 2/
│     └─ data.csv
└─ 2/
   ├─ 1/
   │  └─ data.csv
   └─ 2/
      └─ data.csv

julia> mv(t, r"^([^/]*)/([^/]*)/data.csv\$", s"\\1/\\2.csv")
dir/
├─ 1/
│  ├─ 1.csv
│  └─ 2.csv
└─ 2/
   ├─ 1.csv
   └─ 2.csv
```
"""
function mv(t::FileTree, from_path::Regex, to_path::SubstitutionString; combine=_merge_error, associative=false)
    setparent!(regex_rewrite_tree(t, from_path, to_path, combine; associative=associative))
end

"""
    mergewith(combine, t1::FileTree, t2::FileTree)

Merge two FileTrees. If files at the same path contain values, the `combine` callback will
be called with their values to result in a new value.

Equivalent to calling `merge(t1, t2; combine=combine)`
"""
Base.mergewith(combine, t1::Node, t2::Node; kwargs...) = merge(t1, t2; combine, kwargs...)

"""
    merge(t1::FileTree, t2::FileTree; combine)

Merge two FileTrees. If files at the same path contain values, the `combine` callback will
be called with their values to result in a new value.

If one of the dirs does not have a value, its corresponding argument will be `NoValue()`
If any of the values is lazy, the output value is lazy as well.
"""
Base.merge(x::Node, y::Node; kws...) = setparent(_merge(x, y; kws...)) # We can't be 100% sure _merge returns a copy here...

function _merge(x::Node, y::Node; combine=_merge_error, kws...)
    name(x) == name(y) ? apply_combine(combine, x, y) : FileTree(nothing, ".", [x,y], NoValue())
end


################################# touch #############################

function _mknode(T, t, path::PathLike, value)
    spath = Path(path).segments
    subdir = if T == File
        T(nothing, spath[end], value)
    else
        T(nothing, spath[end], [], value)
    end

    if length(spath) == 1
        merge(t, maketree(name(t) => [subdir]))
    else
        p = joinpath(spath[1:end-1]...)
        attach(t, p, subdir)
    end
end

"""
    touch(t::FileTree, path::AbstractString; value)

Create an file node at `path` in the tree. Does not contain any value by default.
"""
function touch(t::FileTree, path::PathLike; value=NoValue())
    setparent(_mknode(File, t, path, value))
end


################################# mkpath #############################

"""
    mkpath(t::FileTree, path::AbstractString; value)

Create a directory node at `path` in the tree. Does not contain any value by default.
"""
function mkpath(t::FileTree, path::PathLike; value=NoValue())
    _mknode(FileTree, t, path, value)
end

struct UndefMergeError end
_merge_error(x, y) = throw(UndefMergeError())


################################# clip #############################

"""
    clip(t, n; combine)

Remove `n` top-level directories. `combine` will be called
to merge any nodes with equal names found at any level being clipped.
"""
function clip(t, n; combine=_merge_error)
    n==0 && return t
    cs = map(children(t)) do x
        y = clip(x, n-1)
    end
    reduce((x,y)->merge(x,y,combine=combine), cs) |> setparent
end
