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
    t1 = foldl((x, acc) -> acc => [x], [t′; reverse(spath)...]) |> maketree
    merge(t, maketree(name(t)=>[t1]); combine=combine)
end

# rewrite `tree` according by performing string search and replace on every
# path use `combine` to overwrite multiple files which map to the same path
function regex_rewrite_tree(tree, from_path, to_path, combine)
    newtree = maketree(name(tree)=>[])
    for x in Leaves(tree)
        newname = replace(canonical_path(path(x)), from_path => to_path)
        dir = dirname(newname)
        dir = isempty(dir) ? "." : dir
        newtree = attach(newtree,
                         dir,
                         rename(x, basename(newname));
                         combine=combine)
    end
    newtree
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
    if !issorted(cs, by=name)
        sort!(cs, by=name)
    end
    i = 0
    prev = nothing
    out = []
    for c in cs
        if prev == name(c)
            out[end] = apply_combine(combine, c, out[end])
        else
            push!(out, c)
        end
        prev = name(c)
    end
    map(identity, out)
end

# flatten folders named  "." into the parent directory.
function normdots(x::FileTree; combine=_merge_error)
    c2 = map(children(x)) do y
        z=normdots(y; combine=combine)
        name(z) == "." ? children(z) : [z]
    end |> Iterators.flatten |> collect
    FileTree(x; children=_combine(c2, combine))
end

normdots(x::File; kw...) = x


################################ rm ################################

"""
    diff(t1::FileTree, t2::FileTree)

For each node in `t2` remove a node in `t1` at the same path if it exists.
Returns the difference tree.
"""
function Base.diff(t1::FileTree, t2::FileTree)
    if name(t1) == name(t2)
        t2_names = name.(children(t2))
        cs = []
        for x in children(t1)
            idx = findfirst(==(name(x)), t2_names)
            if !isnothing(idx)
                if t2[idx] isa File
                    @assert x isa File
                elseif x isa FileTree && t2[idx] isa FileTree
                    d = diff(x, t2[idx])
                    if !isempty(d)
                        push!(cs, d)
                    end
                end
            else
                push!(cs, x)
            end
        end
        FileTree(t1; children=cs) |> setparent
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
       to_path::SubstitutionString; combine)

copy nodes in the file tree whose path matches the `from_tree` regular expression pattern
by renaming it to `to_path` pattern. Any sub-pattern in `from_path` which is surrounded by
paranthesis will be read as a matched substring which can be accessed in the to_path
substitution pattern using \\1, \\2 etc. positional matches.

If a file overwrites an existing node after copy, `combine` will be called to combine
them together. By default `combine` will error.

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
function cp(t::FileTree, from_path::Regex, to_path::SubstitutionString; combine=_merge_error)
    matches = t[from_path]
    isempty(matches) && return t

    newtree = regex_rewrite_tree(matches, from_path, to_path, combine)
    merge(t, newtree; combine=combine)
end

"""
    merge(t1::FileTree, t2::FileTree; combine)

Merge two FileTrees. If files at the same path contain values, the `combine` callback will
be called with their values to result in a new value.

If one of the dirs does not have a value, its corresponding argument will be `NoValue()`
If any of the values is lazy, the output value is lazy as well.
"""
function Base.merge(t1::FileTree, t2::FileTree; combine=_merge_error, dotnorm=true)
    bigt = if name(t1) == name(t2)
        t2_names = name.(children(t2))
        t2_merged = zeros(Bool, length(t2_names))
        cs = []
        for x in children(t1)
            idx = findfirst(==(name(x)), t2_names)
            if !isnothing(idx)
                y = t2[idx]
                if y isa FileTree
                    push!(cs, merge(x, y; combine=combine, dotnorm=false))
                else
                    push!(cs, apply_combine(combine, x, y))
                end
                t2_merged[idx] = true
            else
                push!(cs, x)
            end
        end
        FileTree(t1; children=vcat(cs, children(t2)[map(!, t2_merged)]))
    else
        FileTree(nothing, ".", [t1, t2], NoValue())
    end |> setparent
    dotnorm ? normdots(bigt; combine=combine) : bigt
end


################################ mv ################################

"""
    mv(t::FileTree,
       from_path::Regex,
       to_path::SubstitutionString; combine)

move nodes in the file tree whose path matches the `from_tree` regular expression pattern
by renaming it to `to_path` pattern. Any sub-pattern in `from_path` which is surrounded by
paranthesis will be read as a matched substring which can be accessed in the to_path
substitution pattern using \\1, \\2 etc. positional matches.

If a file overwrites an existing node after copy, `combine` will be called to combine
them together. By default `combine` will error.

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
function mv(t::FileTree, from_path::Regex, to_path::SubstitutionString; combine=_merge_error)
    matches = t[from_path]
    isempty(matches) && return t

    newtree = regex_rewrite_tree(matches, from_path, to_path, combine)
    merge(diff(t, matches), newtree; combine=combine)
end
function Base.merge(x::Node, y::Node; combine=_merge_error)
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
    _mknode(File, t, path, value)
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
