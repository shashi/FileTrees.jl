
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
- `value::Any` -- the value at the node, if no value is present, a `NoValue()` sentinal value.

    FileTree(tree::FileTree; parent, name, children, value)

Copy over all fields from `tree`, but use any fields provided as keyword arguments.

    FileTree(dirname::String)

Construct a `FileTree` to reflect directory from disk in the current working directory.
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

FileTree(dir) = FileTree(nothing, dir)

function FileTree(parent, dir)
    children = []
    parent′ = FileTree(parent, dir, children)

    ls = readdir(dir)
    cd(dir) do
        children′ = map(ls) do f
            if isdir(f)
                FileTree(parent′, f)
            else
                File(parent′, f)
            end
        end
        append!(children, children′)
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
    setparent(node::Union{FileTree, File}, parent)

Return a copy of node with `parent` set as the parent.
"""
function setparent(x::FileTree, parent=parent(x))
    p = FileTree(x, parent=parent, children=copy(x.children))
    copy!(p.children, setparent.(x.children, (p,)))
    p
end

Base.show(io::IO, d::FileTree) = AbstractTrees.print_tree(io, d)

"""
    File(parent, name, value=NoValue())

#### Fields:

- `parent::Union{FileTree, Nothing}` -- The parent node. `nothing` if it's the root node.
- `name::String` -- Name of the root.
- `value::Any` -- the value at the node, if no value is present, a `NoValue()` sentinal value.
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

Base.show(io::IO, f::File) = print(io, string("File(", path(f), ")"))

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
        for c in tree
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
            FileTree(tree; children=cs)
        end
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

function path(d::Node)
    parent(d) === nothing && return Path(d.name)
    path(parent(d)) / Path(d.name)
end

Base.dirname(d::Node) = dirname(path(d))

"""
    `node[]`

Get the value stored in the node. `NoValue()` is
returned if there is no value stored.
"""
Base.getindex(d::Node) = d.value

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

walk can be either `FileTrees.postwalk` or `FileTrees.postwalk`.
"""
function Base.map(f, tree::FileTree; walk=postwalk, dirs=true)
    walk(tree, collect_children=identity) do n
        (dirs || x isa File) ? f(n) : n
    end
end

"""
    map(f, tree::FileTree; walk=FileTrees.postwalk, dirs=true)

apply `f` to every node in the tree. To only visit File nodes, pass `dirs=false`.

walk can be either `FileTrees.postwalk` or `FileTrees.postwalk`.

    filter(f, tree::FileTree; walk=FileTrees.postwalk, dirs=true)

remove every node `x` from `tree` where `f(x)` is `true`. `f(x)` must return a boolean value.
"""
function Base.filter(f, tree::FileTree; walk=prewalk, dirs=true)
    walk(tree, collect_children=cs->filter(!isnothing, cs)) do n
        (dirs || x isa File) ? (f(n) ? n : nothing) : n
    end
end
