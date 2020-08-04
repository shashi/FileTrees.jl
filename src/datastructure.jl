using DataStructures
using AbstractTrees
import AbstractTrees: children

export name, path, maketree
struct NoValue end

struct FileTree
    parent::Union{FileTree, Nothing}
    name::String
    children::Vector
    value::Any
end

FileTree(parent, name, children) = FileTree(parent, name, children, NoValue())

function Base.isequal(f1::FileTree, f2::FileTree)
    isequal(f1.name, f2.name) &&
    isequal(f1.children, f2.children) &&
    isequal(f1.value, f2.value)
end

# convenience method to replace a few parameters
# and leave others unchanged
function FileTree(t::FileTree;
                  parent=t.parent,
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

children(d::FileTree) = d.children

parent(f::FileTree) = f.parent

name(f::FileTree) = f.name

Base.isempty(d::FileTree) = isempty(d.children)

function rename(x::FileTree, newname)
    set_parent(FileTree(x, name=newname))
end

function set_parent(x::FileTree, parent=x.parent)
    p = FileTree(x, parent=parent, children=copy(x.children))
    copy!(p.children, set_parent.(x.children, (p,)))
    p
end

Base.show(io::IO, d::FileTree) = AbstractTrees.print_tree(io, d)

struct File
    parent::Union{Nothing, FileTree}
    name::String
    value::Any
end

File(parent, name) = File(parent, name, NoValue())

function File(f::File; parent=f.parent, name=f.name, value=f.value)
    File(parent, name, value)
end

Base.show(io::IO, f::File) = print(io, "File(" * path(f) * ")")

function AbstractTrees.printnode(io::IO, f::Union{FileTree, File})
    print(io, name(f))
    if hasvalue(f)
        T = typeof(value(f))
        print(io," (", repr(T), ")")
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

set_parent(x::File, parent=x.parent) = File(x, parent=parent)

files(tree::FileTree) = FileTree(tree; children=filter(x->x isa File, tree.children))

subdirs(tree::FileTree) = FileTree(tree; children=filter(x->x isa FileTree, tree.children))

Base.getindex(tree::FileTree, i::Int) = tree.children[i]

function Base.getindex(tree::FileTree, ix::Vector)
    FileTree(tree;
            children=vcat(map(i->(x=tree[i]; i isa Regex ? x.children :  x), ix)...))
end

function Base.getindex(tree::FileTree, i::String)
    spath = splitpath(i)

    if length(spath) > 1
        for s in spath
            tree = tree[s]
        end
        return tree
    end

    idx = findfirst(x->name(x)==i, children(tree))
    if idx === nothing
        error("No file matched getindex $i")
    end
    tree[idx]
end

function Base.getindex(tree::FileTree, i::Regex)
    filtered = filter(r->match(i, r.name) !== nothing, tree.children)
    FileTree(tree.parent, tree.name, filtered)
end

Base.filter(f, x::FileTree; walk=postwalk) =
    walk(n->f(n) ? n : nothing, x; collect_children=cs->filter(!isnothing, cs))

rename(x::File, newname) = File(x, name=newname)

### Stuff agnostic to Dir or File nature of "Node"s

const Node = Union{FileTree, File}

Base.basename(d::Node) = d.name

path(d::Node) = d.parent === nothing ? d.name : joinpath(path(d.parent), d.name)

Base.dirname(d::Node) = dirname(path(d))

value(d::Node) = d.value

hasvalue(x::Node) = !(value(x) isa NoValue)

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

function flatten(t::FileTree; joinpath=(x,y)->"$(x)_$y")
    postwalk(t) do x
        if x isa FileTree
            cs = map(filter(x->x isa FileTree, children(x))) do sd
                map(children(sd)) do thing
                    newname = joinpath(name(sd), name(thing))
                    typeof(thing)(thing; name=newname, parent=x)
                end
            end |> Iterators.flatten |> collect
            leftover = filter(x-> isempty(x) || !(x isa FileTree), children(x))
            return FileTree(x; children=vcat(cs, leftover))
        else
            return x
        end
    end
end

_merge_error(x, y) = error("Files with same name $(name(x)) found at $(dirname(x)) while merging")

"""
    merge(t1, t2)

Merge two FileTrees
"""
function Base.merge(t1::FileTree, t2::FileTree; combine=_merge_error)
    if name(t1) == name(t2)
        t2_names = name.(children(t2))
        t2_merged = zeros(Bool, length(t2_names))
        cs = []
        for x in children(t1)
            idx = findfirst(==(name(x)), t2_names)
            if !isnothing(idx)
                y = t2[idx]
                if t2[idx] isa FileTree
                    push!(cs, merge(x, y; combine=combine))
                else
                    push!(cs, combine(x, y))
                end
                t2_merged[idx] = true
            else
                push!(cs, x)
            end
        end
        FileTree(t1; children=vcat(cs, children(t2)[map(!, t2_merged)])) |> set_parent
    else
        FileTree(nothing, ".", [t1, t2], NoValue())
    end
end


function treediff(t1::FileTree, t2::FileTree)
    if name(t1) == name(t2)
        t2_names = name.(children(t2))
        cs = []
        for x in children(t1)
            idx = findfirst(==(name(x)), t2_names)
            if !isnothing(idx)
                if t2[idx] isa File
                    @assert x isa File
                elseif x isa FileTree && t2[idx] isa FileTree
                    d = treediff(x, t2[idx])
                    if !isempty(d)
                        push!(cs, d)
                    end
                end
            else
                push!(cs, x)
            end
        end
        FileTree(t1; children=cs) |> set_parent
    else
        t1
    end
end

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

maketree(node) = set_parent(_maketree(node))
maketree(node::Vector) = maketree("."=>node)

function attach(t, path::AbstractString, t′)
    spath = splitpath(path)
    t1 = foldl((x, acc) -> acc => [x], [t′; reverse(spath);]) |> maketree
    merge(t, maketree(name(t)=>[t1]))
end

function detach(t, path::AbstractString)
    subtree = t[path]
    spath = splitpath(path)[1:end-1]
    t1 = foldl((x, acc) -> acc => [x], [subtree; reverse(spath);]) |> maketree
    subtree, treediff(t, t1)
end


function clip(t, n)
    n==0 && return t
    if length(children(t)) == 1
        clip(first(children(t)), n-1)
    else
        xs = [clip(c, n-1) for c in children(t)]
        cs = map(x->name(x) == "." ? children(x) : [x], xs) |> Iterators.flatten
        FileTree(nothing, ".", collect(cs), NoValue())
    end
end

function Base.mv(t, from_path, to_path)
    subt, t′ = detach(t, from_path)
    attach(t′, to_path, subt)
end

function Base.cp(t, from_path, to_path)
    subt, _ = detach(t, from_path)
    attach(t, to_path, subt)
end
