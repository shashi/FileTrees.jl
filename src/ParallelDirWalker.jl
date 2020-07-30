module ParallelDirWalker

export DirTree

using DataStructures
using AbstractTrees

struct File
    name::String
    val::Any
end

AbstractTrees.children(d::File) = ()
AbstractTrees.printnode(io::IO, f::File) = print(io, f.name)

struct DirTree
    dirname::String
    name::String
    children::Vector{Union{File, DirTree}}
end

AbstractTrees.children(d::DirTree) = d.children
AbstractTrees.printnode(io::IO, f::DirTree) = print(io, f.name)
Base.show(io::IO, d::DirTree) = AbstractTrees.print_tree(io, d)

DirTree(t::DirTree;
        dirname=t.dirname,
        name=t.name,
        children=t.children) = DirTree(dirname, name, children)

function DirTree(dir)
    dname = dirname(dir)
    children = map(readdir(dir)) do f
        filepath = joinpath(dir, f)
        if isdir(filepath)
            DirTree(filepath)
        else
            File(basename(filepath), nothing)
        end
    end
    DirTree(dname, basename(dir), children)
end

files(tree::DirTree) = DirTree(tree.dirname, tree.name, filter(x->x isa File, tree.children))
dirs(tree::DirTree) = DirTree(tree.dirname, tree.name, filter(x->x isa DirTree, tree.children))
Base.getindex(tree::DirTree, i::Int) = tree.children[i]
Base.getindex(tree::DirTree, i::String) = _getindex(x->x==i, tree, i)
function Base.getindex(tree::DirTree, i::Regex)
    filtered = filter(r->match(i, r.name) !== nothing, tree.children)
    DirTree(tree.dirname, tree.name, filtered)
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
function _getindex(f, tree::DirTree, repr)
    idx = findfirst(f, tree.children)
    if idx === nothing
        error("No file matched getindex $repr")
    end
    tree.children[i]
end


#=

d = maketree("dir") #-> DirTree
d["subdir"] #-> DirTree

d1 = map(f->DataFrame(CSV.File(f)), dirtree)
d2 = map(df->(df.foo = parse(Int, foo); df), d1)

dir(dirname, subtrees) = ... # DirTree(Dict(dirname=>subtree)

d2 = save(dir("dirname", d2)) do io
    write(rand(UInt8, 100))
end

function Base.getindex(d::DirTree, idx)
end


"""
All the files in the whole subtree
"""
leaves(d::DirTree)

"""
Apply f to every node in d
and return the same directory structure
"""
function map(f, d::DirTree)
end

function reduce(f, d::DirTree)
end

=#
end # module

