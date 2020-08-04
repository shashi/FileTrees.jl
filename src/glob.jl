using Glob
using DataStructures

import Glob: GlobMatch

export @glob_str

function FileTree(g::GlobMatch)
    name = "."
    x = if g.pattern[1] isa AbstractString
        name = g.pattern[1]
        _glob_filter(FileTree(g.pattern[1]), g.pattern...)
    else
        _glob_filter(FileTree("."), ".", g.pattern...)
    end

    if isnothing(x)
        # empty with only the dirname
        FileTree(nothing, name, [], NoValue())
    else
        set_parent(x)
    end
end

function Base.getindex(t::FileTree, g::GlobMatch)
    sub = _glob_filter(t, name(t), g.pattern...)
    if sub === nothing
        error("$g did not match in tree")
    end
    sub
end

struct Skip end

_occursin(p::AbstractString, x) = p == x
_occursin(p, x) = occursin(p, x)

_glob_filter(t::FileTree) = t
_glob_filter(t::File) = t

function _glob_filter(t::FileTree, p, ps...)
    if _occursin(p, name(t))
        if isempty(children(t)) && (isempty(ps) || (ps[1] isa AbstractString && isempty(ps[1])))
            return t
        end
        cs = filter(!isnothing, map(c->_glob_filter(c, ps...), children(t)))
        if isempty(cs)
            return nothing
        else
            return FileTree(t, children=cs)
        end
    else
        return nothing
    end
end

_glob_filter(t::File, p) = _occursin(p, name(t)) ? File(nothing, name(t)) : nothing
_glob_filter(t::File, p...) = nothing

function detach(t, path::GlobMatch)
    subtree = t[path]
    i = findfirst(x -> !(x isa AbstractString), path.pattern)
    node = if i == nothing
        clip(subtree, length(path.pattern)-1)
    else
        clip(subtree, i-1)
    end
    # the returned value has the full structure from the root of the tree
    node, treediff(t, subtree)
end

