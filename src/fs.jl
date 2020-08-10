function attach(t, path::AbstractString, t′; combine=_merge_error)
    spath = splitpath(path)
    t1 = foldl((x, acc) -> acc => [x], [t′; reverse(spath);]) |> maketree
    merge(t, maketree(name(t)=>[t1]); combine=combine)
end

function _rewrite_tree(tree, from_path, to_path, combine)
    newtree = maketree(name(tree)=>[])
    for x in Leaves(tree)
        newname = replace(path(x), from_path => to_path)
        dir = dirname(newname)
        dir = isempty(dir) ? "." : dir
        newtree = attach(newtree,
                         dir,
                         rename(x, basename(newname));
                         combine=combine)
    end
    newtree
end

"""
    mv(t::FileTree, from_path::Regex, to_path::SubstitutionString; combine)

move nodes in the file tree whose path matches the `from_tree` regular expression pattern
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

    newtree = _rewrite_tree(matches, from_path, to_path, combine)
    merge(diff(t, matches), newtree; combine=combine)
end

"""
    cp(t::FileTree, from_path::Regex, to_path::SubstitutionString; combine)

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

    newtree = _rewrite_tree(matches, from_path, to_path, combine)
    merge(t, newtree; combine=combine)
end

# getindex but return the rooted tree 
function _getsubtree(x, path::AbstractString)
    _getsubtree(x, GlobMatch(splitpath(path)))
end
_getsubtree(x, path) = x[path]

"""
    rm(t::FileTree, pattern)

remove nodes which match `pattern` from the file tree.
"""
rm(t::FileTree, path) = diff(t, _getsubtree(t, path))

function _mknode(T, t, path::AbstractString, value)
    spath = splitpath(path)
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
function touch(t::FileTree, path::AbstractString; value=NoValue())
    _mknode(File, t, path, value)
end

"""
    mkpath(t::FileTree, path::AbstractString; value)

Create a directory node at `path` in the tree. Does not contain any value by default.
"""
function mkpath(t::FileTree, path::AbstractString; value=NoValue())
    _mknode(FileTree, t, path, value)
end
