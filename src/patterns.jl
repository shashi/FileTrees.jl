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

Base.empty(d::Dir) = Dir(d; children=[])

_occursin(p::AbstractString, x) = p == x
_occursin(p, x) = occursin(p, x)

_glob_filter(t::Node, ps...) = _glob_map(identity, x->nothing, t, ps...)

_glob_map(yes, no, t::Node) = yes(t) # occurs when there's no pattern left to match

function _glob_map(yes, no, t::Dir, p, ps...)
    if _occursin(p, name(t))
        if isempty(children(t)) && (isempty(ps) || (ps[1] isa AbstractString && isempty(ps[1])))
            return yes(t)
        end
        cs = filter(!isnothing, map(c->_glob_map(yes, no, c, ps...), children(t)))
        if isempty(cs)
            return no(t)
        else
            return Dir(t, children=cs)
        end
    else
        return no(t)
    end
end

_glob_map(yes, no, t::File, p) = _occursin(p, name(t)) ? yes(t) : no(t)
_glob_map(yes, no, t::File, p...) = no(t)

function mapmatches(f, t::Dir, g::GlobMatch)
    _glob_map(f, identity, t, g.pattern...) |> set_parent
end

#### Regexes

"""
    getindex(t::Dir, regex::Regex)
    t[regex]

Returns a filtered trees where paths match the `regex` regular expression.
Surround the regular expression in `^` and `\$` (to match the entire string).
"""
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
