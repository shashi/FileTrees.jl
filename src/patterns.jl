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
        setparent(x)
    end
end

function Base.getindex(t::FileTree, g::GlobMatch)
    sub = _glob_filter(t, name(t), g.pattern...)
    if sub === nothing
        error("$g did not match in tree")
    end
    sub
end

_occursin(p::AbstractString, x) = p == x
_occursin(p, x) = occursin(p, x)

_glob_filter(t::Node, ps...) = _glob_map(identity, x->nothing, t, ps...)

_glob_map(yes, no, t::File) = yes(t)

_glob_map(yes, no, t::FileTree) = yes(t)

function _glob_map(yes, no, t::FileTree, p, ps...)
    if _occursin(p, name(t))
        if isempty(children(t)) && (isempty(ps) || (ps[1] isa AbstractString && isempty(ps[1])))
            return yes(t)
        end
        cs = filter(!isnothing, map(c->_glob_map(yes, no, c, ps...), children(t)))
        if isempty(cs)
            return no(t)
        else
            return FileTree(t, children=cs)
        end
    else
        return no(t)
    end
end

_glob_map(yes, no, t::File, p) = _occursin(p, name(t)) ? yes(t) : no(t)
_glob_map(yes, no, t::File, p...) = no(t)

#### Regexes

"""
    getindex(t::FileTree, regex::Regex)
    t[regex]

Returns a filtered trees where paths match the `regex` regular expression.
Surround the regular expression in `^` and `\$` (to match the entire string).
"""

function Base.getindex(x::Union{FileTree, File}, regex::Regex)
    t = _regex_map(identity, x->nothing, x, regex)
    isnothing(t) ?  empty(x) : t
end

function _regex_map(yes, no, t::FileTree, regex::Regex, toplevel=true)
    if !toplevel && !isnothing(match(regex, canonical_path(path(t))))
        return yes(t)
    end

    cs = map(children(t)) do x
        if toplevel
            x = setparent(x, nothing)
        end
        _regex_map(yes, no, x, regex, false)
    end

    cs = filter(!isnothing, cs)

    if isempty(cs)
        return no(t)
    else
        return FileTree(t; children=cs)
    end
end

function _regex_map(yes, no, t::File, regex::Regex, toplevel=false)
    !isnothing(match(regex, canonical_path(path(t)))) ? yes(t) : no(t)
end
