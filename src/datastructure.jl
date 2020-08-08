using AbstractTrees
import AbstractTrees: children

export name, path, maketree
struct NoValue end

"""
    Dir(parent, name, children, value)

    Dir(d::Dir; parent, name, children, value)

    Dir(dirname::String)

    Dir(g::Glob)
"""
struct Dir
    parent::Union{Dir, Nothing}
    name::String
    children::Vector
    value::Any
end

Dir(parent, name, children) = Dir(parent, name, children, NoValue())

function Base.isequal(f1::Dir, f2::Dir)
    !isequal(f1.name, f2.name) && return false

    c1 = issorted(f1.children, by=name) ? f1.children : sort(f1.children, by=name)
    c2 = issorted(f2.children, by=name) ? f2.children : sort(f2.children, by=name)

    !isequal(c1, c2) && return false
    isequal(f1.value, f2.value)
end

# convenience method to replace a few parameters
# and leave others unchanged
function Dir(t::Dir;
                  parent=t.parent,
                  name=t.name,
                  children=t.children,
                  value=t.value)
    Dir(parent, name, children, value)
end

(f::Dir)(; kw...) = Dir(f; kw...)

Dir(dir) = Dir(nothing, dir)

function Dir(parent, dir)
    children = []
    parent′ = Dir(parent, dir, children)

    ls = readdir(dir)
    cd(dir) do
        children′ = map(ls) do f
            if isdir(f)
                Dir(parent′, f)
            else
                File(parent′, f)
            end
        end
        append!(children, children′)
    end

    parent′
end

children(d::Dir) = d.children

parent(f::Dir) = f.parent

name(f::Dir) = f.name

Base.isempty(d::Dir) = isempty(d.children)

function rename(x::Dir, newname)
    set_parent(Dir(x, name=newname))
end

function set_parent(x::Dir, parent=x.parent)
    p = Dir(x, parent=parent, children=copy(x.children))
    copy!(p.children, set_parent.(x.children, (p,)))
    p
end

Base.show(io::IO, d::Dir) = AbstractTrees.print_tree(io, d)

struct File
    parent::Union{Nothing, Dir}
    name::String
    value::Any
end

File(parent, name) = File(parent, name, NoValue())

function File(f::File; parent=f.parent, name=f.name, value=f.value)
    File(parent, name, value)
end

Base.show(io::IO, f::File) = print(io, "File(" * path(f) * ")")

function AbstractTrees.printnode(io::IO, f::Union{Dir, File})
    print(io, name(f))
    if f isa Dir
        print(io, "/")
    end
    if hasvalue(f)
        print(io," (", summary(value(f)), ")")
    end
end

File(parent, name::String) = File(parent, name, NoValue())

(f::File)(; kw...) = File(f; kw...)

function Base.isequal(f1::File, f2::File)
    f1.name == f2.name && isequal(f1.value, f2.value)
end

children(d::File) = ()

parent(f::File) = f.parent

name(f::File) = f.name

Base.isempty(d::File) = false

set_parent(x::File, parent=x.parent) = File(x, parent=parent)

files(tree::Dir) = Dir(tree; children=filter(x->x isa File, tree.children))

subdirs(tree::Dir) = Dir(tree; children=filter(x->x isa Dir, tree.children))

Base.getindex(tree::Dir, i::Int) = tree.children[i]

function Base.getindex(tree::Dir, ix::Vector)
    Dir(tree;
            children=vcat(map(i->(x=tree[i]; i isa Regex ? x.children :  x), ix)...))
end

function Base.getindex(tree::Dir, i::String)
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

Base.filter(f, x::Dir; walk=postwalk) =
    walk(n->f(n) ? n : nothing, x; collect_children=cs->filter(!isnothing, cs))

rename(x::File, newname) = File(x, name=newname)

### Stuff agnostic to Dir or File nature of "Node"s

const Node = Union{Dir, File}

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
    return Dir(nothing, name, cs, value)
end

maketree(node) = set_parent(_maketree(node))
maketree(node::Vector) = maketree("."=>node)

Base.basename(d::Node) = d.name

path(d::Node) = d.parent === nothing ? d.name : joinpath(path(d.parent), d.name)

Base.dirname(d::Node) = dirname(path(d))

value(d::Node) = d.value

hasvalue(x::Node) = !(value(x) isa NoValue)

## Tree walking

function prewalk(f, t::Dir; collect_children=identity)
    x = f(t)
    if x isa Dir
        cs = map(c->prewalk(f, c; collect_children=collect_children), t.children)
        Dir(x; children=collect_children(cs))
    else
        return x
    end
end

prewalk(f, t::File; collect_children=identity) = f(t)

function postwalk(f, t::Dir; collect_children=identity)
    cs = map(c->postwalk(f, c; collect_children=collect_children), t.children)
    f(Dir(t; children=collect_children(cs)))
end

postwalk(f, t::File; collect_children=identity) = f(t)

function flatten(t::Dir; joinpath=(x,y)->"$(x)_$y")
    postwalk(t) do x
        if x isa Dir
            cs = map(filter(x->x isa Dir, children(x))) do sd
                map(children(sd)) do thing
                    newname = joinpath(name(sd), name(thing))
                    typeof(thing)(thing; name=newname, parent=x)
                end
            end |> Iterators.flatten |> collect
            leftover = filter(x-> isempty(x) || !(x isa Dir), children(x))
            return Dir(x; children=vcat(cs, leftover))
        else
            return x
        end
    end
end

_merge_error(x, y) = error("Files with same name $(name(x)) found at $(dirname(x)) while merging")

"""
    merge(t1::Dir, t2::Dir; combine)

Merge two Dirs. If files at the same path contain values, the `combine` callback will
be called with their values to result in a new value.

If one of the dirs does not have a value, its corresponding argument will be `NoValue()`
If any of the values is lazy, the output value is lazy as well.
"""
function Base.merge(t1::Dir, t2::Dir; combine=_merge_error, dotnorm=true)
    bigt = if name(t1) == name(t2)
        t2_names = name.(children(t2))
        t2_merged = zeros(Bool, length(t2_names))
        cs = []
        for x in children(t1)
            idx = findfirst(==(name(x)), t2_names)
            if !isnothing(idx)
                y = t2[idx]
                if y isa Dir
                    push!(cs, merge(x, y; combine=combine, dotnorm=false))
                else
                    push!(cs, apply_combine(combine, x, y))
                end
                t2_merged[idx] = true
            else
                push!(cs, x)
            end
        end
        Dir(t1; children=vcat(cs, children(t2)[map(!, t2_merged)]))
    else
        Dir(nothing, ".", [t1, t2], NoValue())
    end |> set_parent
    dotnorm ? normdots(bigt; combine=combine) : bigt
end

function apply_combine(f, x, y)
    (!hasvalue(x) && !hasvalue(y)) && return y
    x(value=maybe_lazy(f)(value(x), value(y)))
end

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

function normdots(x::Dir; combine=_merge_error)
    c2 = map(children(x)) do y
        z=normdots(y; combine=combine)
        name(z) == "." ? children(z) : [z]
    end |> Iterators.flatten |> collect
    Dir(x; children=_combine(c2, combine))
end

normdots(x::File; kw...) = x

function Base.merge(x::Node, y::Node; combine=_merge_error)
    name(x) == name(y) ? apply_combine(combine, x, y) : Dir(nothing, ".", [x,y], NoValue())
end

"""
    diff(t1::Dir, t2::Dir)

For each node in `t2` remove a node in `t1` at the same path if it exists.
Returns the reduced tree.
"""
function Base.diff(t1::Dir, t2::Dir)
    if name(t1) == name(t2)
        t2_names = name.(children(t2))
        cs = []
        for x in children(t1)
            idx = findfirst(==(name(x)), t2_names)
            if !isnothing(idx)
                if t2[idx] isa File
                    @assert x isa File
                elseif x isa Dir && t2[idx] isa Dir
                    d = diff(x, t2[idx])
                    if !isempty(d)
                        push!(cs, d)
                    end
                end
            else
                push!(cs, x)
            end
        end
        Dir(t1; children=cs) |> set_parent
    else
        t1
    end
end

function attach(t, path::AbstractString, t′; combine=_merge_error)
    spath = splitpath(path)
    t1 = foldl((x, acc) -> acc => [x], [t′; reverse(spath);]) |> maketree
    merge(t, maketree(name(t)=>[t1]); combine=combine)
end

function Base.detach(t, path::AbstractString)
    subtree = t[path]
    spath = splitpath(path)[1:end-1]
    t1 = foldl((x, acc) -> acc => [x], [subtree; reverse(spath);]) |> maketree
    subtree, diff(t, maketree(name(t)=>[t1]))
end

function Base.detach(t, regex::Regex)
    subtree = t[regex]
    subtree, diff(t, subtree)
end

function clip(t, n; combine=_merge_error)
    n==0 && return t
    cs = map(children(t)) do x
        y = clip(x, n-1)
    end
    reduce((x,y)->merge(x,y,combine=combine), cs) |> set_parent
end
