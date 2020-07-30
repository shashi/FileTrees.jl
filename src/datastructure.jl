using DataStructures
using AbstractTrees
import AbstractTrees: children

export name, path
struct NoValue end

struct DirTree
    parent::Union{DirTree, Nothing}
    name::String
    children::Vector
    value::Any
end

DirTree(parent, name, children) = DirTree(parent, name, children, NoValue())

# convenience method to replace a few parameters
# and leave others unchanged
function DirTree(t::DirTree; parent=t.parent, name=t.name, children=t.children, value=t.value)
    DirTree(parent, name, children, value)
end

DirTree(dir) = DirTree(nothing, dir)

function DirTree(parent, dir)
    children = []
    parent′ = DirTree(parent, dir, children)

    ls = readdir(dir)
    cd(dir) do
        children′ = map(ls) do f
            if isdir(f)
                DirTree(parent′, f)
            else
                File(parent′, f)
            end
        end
        append!(children, children′)
    end

    parent′
end

children(d::DirTree) = d.children

parent(f::DirTree) = f.parent

name(f::DirTree) = f.name

Base.isempty(d::DirTree) = isempty(d.children)

AbstractTrees.printnode(io::IO, f::DirTree) = print(io, f.name)

Base.show(io::IO, d::DirTree) = AbstractTrees.print_tree(io, d)

struct File
    parent::DirTree
    name::String
    value::Any
end

File(parent, name) = File(parent, name, NoValue())

function File(f::File; parent=f.parent, name=f.name, value=f.value)
    File(parent, name, value)
end

Base.show(io::IO, f::File) = print(io, "File(" * path(f) * ")")

File(parent, name::String) = File(parent, name, nothing)

children(d::File) = ()

parent(f::File) = f.parent

name(f::File) = f.name

Base.isempty(d::File) = false

AbstractTrees.printnode(io::IO, f::File) = print(io, f.name)

files(tree::DirTree) = DirTree(tree; children=filter(x->x isa File, tree.children))
subdirs(tree::DirTree) = DirTree(tree; children=filter(x->x isa DirTree, tree.children))

Base.getindex(tree::DirTree, i::Int) = tree.children[i]
Base.getindex(tree::DirTree, i::String) = _getindex(x->x.name==i, tree, i)
function Base.getindex(tree::DirTree, i::Regex)
    filtered = filter(r->match(i, r.name) !== nothing, tree.children)
    DirTree(tree.parent, tree.name, filtered)
end
function _getindex(f, tree::DirTree, repr)
    idx = findfirst(f, tree.children)
    if idx === nothing
        error("No file matched getindex $repr")
    end
    tree.children[idx]
end

Base.filter(f, x::DirTree) = filterrecur(f, x)

function filterrecur(f, x)
    if f(x)
        if x isa DirTree
            children = filter(!isnothing, filterrecur.(f, x.children))
            return DirTree(x; children=children)
        else
            return x
        end
    else
        return nothing
    end
end


### Stuff agnostic to Dir or File nature of "Node"s

const Node = Union{DirTree, File}

Base.basename(d::Node) = d.name

path(d::Node) = d.parent === nothing ? d.name : joinpath(path(d.parent), d.name)

Base.dirname(d::Node) = dirname(path(d))

value(d::Node) = d.value

hasvalue(x::Node) = !(value(x) isa NoValue)

rename(x::T, newname) where {T<:Node} = T(x, name=newname)
