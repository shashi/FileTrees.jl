
# when string matching patterns, we always use "/" as the
# delimiter. good luck if your path system allows "/" in
# file names!
canonical_path(p::AbstractPath) = join(p.segments, "/")

struct NoValue end

"""
    FileTree(parent, name, children, value)

#### Fields:

- `parent::Union{FileTree, Nothing}` -- The parent node. `nothing` if it's the root node.
- `name::String` -- Name of the root.
- `children::Vector` -- children
- `value::Any` -- the value at the node, if no value is present, a `NoValue()` sentinel value.

    FileTree(tree::FileTree; parent, name, children, value)

Copy over all fields from `tree`, but use any fields provided as keyword arguments.

    FileTree(dirname::String; [sort], [follow_symlinks], [paralleldepth])

Construct a `FileTree` to reflect directory from disk in the current working directory.

If `sort=true` (the default) then each level of the tree will be lexicographically sorted.

If `follow_symlinks=true` (the default) then symbolic links will be followed. Setting this to `true` actually speeds up the construction, 
even if no symbolic links are present as it elides a stat check inside `walkdir`. Only reason to set this to `false` is if there exist
symbolic links that should not be followed.
 
Subdirectories down to `paralleldepth` (default `0`) levels will be read in separate tasks, which can give significant speedups when the directory tree is
wide and I/O latency is high (e.g. NFS).
"""
struct FileTree
    parent::Union{FileTree, Nothing}
    name::String
    children::Vector
    value::Any
end

FileTree(parent, name, children) = FileTree(parent, name, children, NoValue())

function Base.isequal(f1::FileTree, f2::FileTree)
    !isequal(f1.name, f2.name) && return false

    c1 = issorted(f1.children, by=name) ? f1.children : sort(f1.children, by=name)
    c2 = issorted(f2.children, by=name) ? f2.children : sort(f2.children, by=name)

    !isequal(c1, c2) && return false
    isequal(f1.value, f2.value)
end

# convenience method to replace a few parameters
# and leave others unchanged
function FileTree(t::FileTree;
                  parent=parent(t),
                  name=t.name,
                  children=t.children,
                  value=t.value)
    FileTree(parent, name, children, value)
end

FileTree(dir; kwargs...) = FileTree(nothing, dir; kwargs...)

function FileTree(parent, dir; sort=true, follow_symlinks=true, root="", paralleldepth=0)
    parent′ = FileTree(parent, dir, [])
    for (path, dirs, files) in walkdir(joinpath(root, dir); follow_symlinks)

        if paralleldepth > 0 && length(dirs) > 1
            tasks = [Threads.@spawn FileTree(parent′, d; sort, follow_symlinks, root=path, paralleldepth=paralleldepth-1) for d in dirs]
            append!(parent′.children, fetch.(tasks))
        else
            for d in dirs
                push!(parent′.children, FileTree(parent′, d; sort, follow_symlinks, root=path, paralleldepth=0))
            end
        end
        for file in files
            push!(parent′.children, File(parent′, file))
        end
        if sort
            sort!(parent′.children; by=name)
        end
        break
    end
    parent′
end

"""
    children(node::Union{FileTree, File})

Get the immediate children of a `FileTree` node.
If node is `File` then returns `()`.
"""
children(d::FileTree) = d.children

"""
    parent(node::Union{FileTree, File})

Get the parent node. Returns `nothing` if there are no parents.
"""
parent(f::FileTree) = f.parent

"""
    name(node::Union{FileTree, File})

Get the file or directory name.
"""
name(f::FileTree) = f.name

Base.isempty(d::FileTree) = isempty(d.children)

Base.empty(d::FileTree) = FileTree(d; children=[])

"""
    rename(node::Union{FileTree, File}, newname)

Return a copy of node with `name` set to `newname`.
"""
function rename(x::FileTree, newname)
    setparent(FileTree(x, name=string(newname)))
end

"""
    setvalue(node::Union{FileTree, File}, val)

Return a copy of node with `val` set as the value.
"""
setvalue(x::FileTree, val) = FileTree(x; value=val)

"""
    setparent(node::Union{FileTree, File}, parent; [deep])

Return a copy of node with `parent` set as the parent.
"""
function setparent(x::FileTree, parent=parent(x))
    p = FileTree(x, parent=parent, children=similar(x.children))
    @inbounds for i in eachindex(p.children, x.children)
        p.children[i] =  setparent(x.children[i], p)
    end
    p
end

# Update children without copying them. Only for when we are dead certain we have
# created the whole tree from scratch
function setparent!(x::FileTree, parent=parent(x))
    p = FileTree(x, parent=parent, children=x.children)
    @inbounds for i in eachindex(p.children, x.children)
        p.children[i] =  setparent!(x.children[i], p)
    end
    p
end

Base.show(io::IO, d::FileTree) = AbstractTrees.print_tree(io, d)

"""
    File(parent, name, value=NoValue())

#### Fields:

- `parent::Union{FileTree, Nothing}` -- The parent node. `nothing` if it's the root node.
- `name::String` -- Name of the root.
- `value::Any` -- the value at the node, if no value is present, a `NoValue()` sentinel value.
"""
struct File
    parent::Union{Nothing, FileTree}
    name::String
    value::Any
end

File(parent, name) = File(parent, name, NoValue())

function File(f::File; parent=parent(f), name=f.name, value=f.value)
    File(parent, name, value)
end

Base.show(io::IO, f::File) = print(io, string("File(", Path(f), ")"))

function AbstractTrees.printnode(io::IO, f::Union{FileTree, File})
    print(io, name(f))
    if f isa FileTree
        print(io, "/")
    end
    if hasvalue(f)
        print(io," (", summary(f[]), ")")
    end
end

File(parent, name::String) = File(parent, name, NoValue())

function Base.isequal(f1::File, f2::File)
    f1.name == f2.name && isequal(f1.value, f2.value)
end

children(d::File) = ()

parent(f::File) = f.parent

name(f::File) = f.name

Base.isempty(d::File) = false

Base.empty(d::File) = d

setvalue(x::File, val) = File(x, value=val)

setparent(x::File, parent=parent(x)) = File(x, parent=parent)

setparent!(f::File, args...;kws...) = setparent(f, args...)


Base.getindex(tree::FileTree, i::Int) = tree.children[i]

function Base.getindex(tree::FileTree, ix::Vector)
    FileTree(tree;
            children=vcat(map(i->(x=tree[i]; i isa Regex ? x.children :  x), ix)...))
end

Base.getindex(tree::FileTree, i::AbstractString) = tree[Path(i)]

function Base.getindex(tree::FileTree, i::AbstractPath)
    spath = i.segments

    if length(spath) > 1
        for s in spath
            tree = tree[s]
        end
        return tree
    end
    p = string(i)

    idx = findfirst(x->name(x)==p, children(tree))
    if idx === nothing
        error("No file matched getindex $i")
    end

    tree[idx]
end

function Base.getindex(tree::FileTree, subtree::FileTree; toplevel=true)
    if name(tree) != name(subtree)
        toplevel && error("Root name should match while getindexing with trees")
        return nothing
    else
        namesof_subtree = name.(children(subtree))
        cs = []
        for c in children(tree)
            idx = findfirst(==(name(c)), namesof_subtree)
            if !isnothing(idx)
                rest = c[subtree[idx]]
                if rest !== nothing
                    push!(cs, rest)
                end
            end
        end
        if isempty(cs)
            return nothing
        else
            return FileTree(tree; children=cs)
        end
    end
end

function Base.getindex(f::File, g::File; toplevel=true)
    if name(f) != name(g)
        if toplevel
            error("File not found")
        else
            return nothing
        end
    else
        return f
    end
end


rename(x::File, newname) = File(x, name=string(newname))

### Stuff agnostic to FileTree or File nature of "Node"s

const Node = Union{FileTree, File}

_maketree(node::String) = File(nothing, node, NoValue())
_maketree(node::NamedTuple) = File(nothing, node.name, node.value)
_maketree(node::Pair) = _maketree(node[1], node[2])
_maketree(node::Node) = node

function _maketree(node, children)
    cs = maketree.(children)
    if node isa Node
        return typeof(node)(node; children=cs)
    elseif node isa NamedTuple
        name = node.name
        value = node.value
    else
        name = node
        value = NoValue()
    end
    return FileTree(nothing, name, cs, value)
end

maketree(node) = setparent(_maketree(node))
maketree(node::Vector) = maketree("."=>node)

Base.basename(d::Node) = Path(d.name)

# Internal struct for collecting the path from a Node with minimal overhead
# We reuse it so we don't need to allocate the data array each time we use it
# TaskLocalValue is used to thread safety
struct PathStringBuffer
    data::Vector{UInt8}
end
PathStringBuffer() = PathStringBuffer(Vector{UInt8}[])
const _PATH_STRING_BUFFER = TaskLocalValue{PathStringBuffer}(PathStringBuffer)


function _rpath(buf::PathStringBuffer, f::FileTrees.Node, delim)
    pos = _rpath!(buf, f, 0, delim)
    res = GC.@preserve buf unsafe_string(pointer(buf.data), pos)
    empty!(buf.data)
    res
end

function _rpath!(buf, f::FileTrees.Node, pos::Int, delim::Vector{UInt8})
    if !isnothing(parent(f))
        pos = _rpath!(buf, parent(f), pos, delim)  
        append!(buf.data, delim)
        pos += length(delim)
    end
    n = codeunits(name(f))
    append!(buf.data, n)
    return pos + length(n)
end

# Internal struct for collecting the Path segments from a Node with minimal overhead
# We reuse it so we don't need to allocate the path array each time we use it
# TaskLocalValue is used to thread safety
struct PathStringArray
    path::Vector{String}
end
PathStringArray() = PathStringArray(sizehint!(String[], 4))
const _PATH_STRING_ARRAY = TaskLocalValue{PathStringArray}(PathStringArray)

function _rpath(arr::PathStringArray, f::FileTrees.Node)
    len = _rpath!(arr, f, 1)-1
    ntuple(i -> arr.path[i], len)
end
function _rpath!(arr::PathStringArray, f::FileTrees.Node, n)
    if isnothing(parent(f))
        if length(arr.path) < n
            resize!(arr.path, n)
        end
        arr.path[1] = name(f)
        return 2
    end

    pos = _rpath!(arr, parent(f), n+1) 
    arr.path[pos] = name(f)
    pos+1
end

"""
    Path(file::Union{File, FileTree)

Returns an [`AbstractPath`](https://rofinn.github.io/FilePathsBase.jl/stable/design/#Path-Types-1) object which is the Path of the file from the
root node leading up to this file.
"""
function Path(d::Node) 
    arr =_PATH_STRING_ARRAY[]
    len = _rpath!(arr, d, 1)-1
    Path(ntuple(i -> arr.path[i], len))
end

const _PATH_SEPARATOR = Vector{UInt8}(Base.Filesystem.path_separator)
const _CANONICAL_PATH_SEPARATOR = [UInt8('/')]

path(x::Node) =  _rpath(_PATH_STRING_BUFFER[], x, _PATH_SEPARATOR)
canonical_path(x::Node) = _rpath(_PATH_STRING_BUFFER[], x, _CANONICAL_PATH_SEPARATOR)

Base.dirname(d::Node) = Path(parent(d))

Base.getindex(d::Node) = d.value

"""
    get(node)

Get the value stored in the node. `NoValue()` is
returned if there is no value stored.
"""
Base.get(d::Node) = d.value

"""
    get(node)

Get the value stored in the node. `NoValue()` is
returned if there is no value stored.
"""
function get_doc end # hack to make API docs page show only this.

hasvalue(x::Node) = !(x[] isa NoValue)

## Tree walking

function prewalk(f, t::FileTree; collect_children=identity)
    x = f(t)
    if x isa FileTree
        cs = map(c->prewalk(f, c; collect_children=collect_children), t.children)
        FileTree(x; children=collect_children(cs))
    else
        return x
    end
end

prewalk(f, t::File; collect_children=identity) = f(t)

function postwalk(f, t::FileTree; collect_children=identity)
    cs = map(c->postwalk(f, c; collect_children=collect_children), t.children)
    f(FileTree(t; children=collect_children(cs)))
end

postwalk(f, t::File; collect_children=identity) = f(t)

"""
    map(f, tree::FileTree; walk=FileTrees.postwalk, dirs=true)

apply `f` to every node in the tree. To only visit File nodes, pass `dirs=false`.

walk can be either `FileTrees.postwalk` or `FileTrees.prewalk`.  Which applies the function after recursively walking the tree, or before.
"""
function Base.map(f, tree::FileTree; walk=postwalk, dirs=true)
    walk(tree, collect_children=identity) do n
        (dirs || n isa File) ? f(n) : n
    end
end

"""
    filter(f, tree::FileTree; walk=FileTrees.postwalk, dirs=true)

Return a copy of `tree`, removing nodes for which `f` is `false`. 

The function `f` is passed all nodes (`File`s and `FileTree`s) if `dirs=true` 
and leaf nodes (`File`s) if `dirs=false`.

`walk` can be either `FileTrees.postwalk` or `FileTrees.prewalk`. Which applies the function after recursively walking the tree, or before.
"""
function Base.filter(f, tree::FileTree; walk=prewalk, dirs=true)
    walk(tree, collect_children=cs->filter(!isnothing, cs)) do n
        (dirs || n isa File) ? (f(n) ? n : nothing) : n
    end
end


"""
    values(tree::FileTree; dirs=true)

Get a vector of all non-null values from nodes in the tree.

`dirs=false` will exclude any value stored in `FileTree` sub nodes.
"""
function values_doc end # hack to make api docs work

"""
    values(tree::FileTree; dirs=true)

Get a vector of all non-null values from nodes in the tree.

`dirs=false` will exclude any value stored in `FileTree` sub nodes.
"""
function Base.values(tree::FileTree; dirs=true, iter=PostOrderDFS)
    map(get, Iterators.filter(x->(dirs || x isa File) && hasvalue(x), iter(tree)))
end


"""
    nodes(tree::FileTree, dirs=true)

Get a vector of all nodes in the tree.

`dirs=false` will return only `File` nodes.
"""
function nodes(tree::FileTree; dirs=true, iter=PostOrderDFS)
    collect(Iterators.filter(x->(dirs || x isa File), iter(tree)))
end


"""
    files(tree::FileTree)

Get a vector of all files in the tree.
"""
files(tree::FileTree) = nodes(tree, dirs=false)

"""
    dirs(tree::FileTree, dirs=true)

Get a vector of all directories in the tree.
"""
dirs(tree::FileTree) = filter!(x->x isa FileTree, nodes(tree, dirs=true))
