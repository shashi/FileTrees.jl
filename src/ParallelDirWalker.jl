module ParallelDirWalker

export DirTree, File, path

using DataStructures
using AbstractTrees
import AbstractTrees: children

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
function DirTree(t::DirTree; parent=t.parent, name=t.name, children=t.children)
    DirTree(parent, name, children)
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
    DirTree(tree.dirname, tree.name, filtered)
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

######## load, map over loaded data, save

include("util.jl")
export load, mapvalues, save, NoValue

function load(f, t::DirTree; dirs=false)
    inner = DirTree(t; children=map(c->load(f, c; dirs=dirs), children(t)))
    dirs ? DirTree(inner, value=f(inner)) : inner
end

load(f, t::File; dirs=false) = File(t, value=f(t))

mapvalues(f, x::File) = hasvalue(x) ? File(x, value=f(value(x))) : x

function mapvalues(f, t::DirTree)
    x = DirTree(t, children = mapvalues.(f, t.children))
    hasvalue(x) ? DirTree(x, value=f(value(x))) : x
end

function mapreducevals(g, f, t::DirTree; associative=true)
    x = mapreducevals.(g, f, t.children)
    associative ? assocreduce(g, x) : reduce(g, x)
end

function reducevalues(f, t::DirTree; associative=true, across_dirs=false)
    if associative && across_dirs
    end
end

function save(f, t::DirTree)
    mkpath(path(t))
    foreach(x->save(f, x), children(t))
end

save(f, t::File) = hasvalue(t) && f(t)

end # module

