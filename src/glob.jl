using Glob
using DataStructures

import Glob: GlobMatch

export @glob_str

function DirTree(g::GlobMatch)
    name = "."
    x = if g.pattern[1] isa AbstractString
        name = g.pattern[1]
        _glob_filter(DirTree(g.pattern[1]), g.pattern...)
    else
        _glob_filter(DirTree("."), ".", g.pattern...)
    end

    if isnothing(x)
        # empty with only the dirname
        DirTree(nothing, name, [], NoValue())
    else
        set_parent(x)
    end
end

function Base.filter(g::GlobMatch, t::DirTree)
    _glob_filter(t, g.pattern...)
end

_occursin(p::AbstractString, x) = p == x
_occursin(p, x) = occursin(p, x)

function _glob_filter(t::DirTree, p, ps...)
    if _occursin(p, name(t))
        cs = filter(!isnothing, map(c->_glob_filter(c, ps...), children(t)))
        isempty(cs) && return nothing
        return DirTree(t, children=cs)
    else
        return nothing
    end
end

_glob_filter(t::File, p) = _occursin(p, name(t)) ? File(nothing, name(t)) : nothing
_glob_filter(t::File, p...) = nothing
