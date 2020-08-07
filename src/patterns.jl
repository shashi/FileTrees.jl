using Glob

import Glob: GlobMatch

export @glob_str

function Dir(g::GlobMatch)
    name = "."
    x = if g.pattern[1] isa AbstractString
        name = g.pattern[1]
        _glob_filter(Dir(g.pattern[1]), g.pattern...)
    else
        _glob_filter(Dir("."), ".", g.pattern...)
    end

    if isnothing(x)
        # empty with only the dirname
        Dir(nothing, name, [], NoValue())
    else
        set_parent(x)
    end
end

function Base.getindex(t::Dir, g::GlobMatch)
    sub = _glob_filter(t, name(t), g.pattern...)
    if sub === nothing
        error("$g did not match in tree")
    end
    sub
end

_occursin(p::AbstractString, x) = p == x
_occursin(p, x) = occursin(p, x)

_glob_filter(t::Dir) = t
_glob_filter(t::File) = t

function _glob_filter(t::Dir, p, ps...)
    if _occursin(p, name(t))
        if isempty(children(t)) && (isempty(ps) || (ps[1] isa AbstractString && isempty(ps[1])))
            return t
        end
        cs = filter(!isnothing, map(c->_glob_filter(c, ps...), children(t)))
        if isempty(cs)
            return nothing
        else
            return Dir(t, children=cs)
        end
    else
        return nothing
    end
end

_glob_filter(t::File, p) = _occursin(p, name(t)) ? File(nothing, name(t)) : nothing
_glob_filter(t::File, p...) = nothing

function Base.detach(t, path::GlobMatch)
    subtree = t[path]
    # the returned value has the full structure from the root of the tree
    subtree, treediff(t, subtree)
end


#### Regexes

function Base.getindex(t::Dir, regex::Regex; toplevel=true)
    if !toplevel && !isnothing(match(regex, path(t)))
        return t
    end

    cs = map(children(t)) do x
        if toplevel
            x = set_parent(x, nothing)
        end
        getindex(x, regex, toplevel=false)
    end

    Dir(t; children=filter(x->!isnothing(x) && !isempty(x), cs))
end

function Base.getindex(t::File, regex::Regex; toplevel=false)
    !isnothing(match(regex, path(t))) ? t : nothing
end
