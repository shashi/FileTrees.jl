# getindex on patterns

#### Globs

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
        # This path (maybe a FileTree) matches. And is the end of the pattern.
        if (isempty(ps) || (ps[1] isa AbstractString && isempty(ps[1])))
            return yes(t)
        end

        # Full path hasn't been matched, continue into the children.
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


"""
    mapsubtrees(f, t::FileTree, pattern::Union{GlobMatch, Regex})

For every node that matches the pattern provided, apply the function `f`.

If `f` returns either a `File` or `FileTree`, this new node will replace the matched node.

If `f` returns `nothing`, the matched node will be deleted

If `f` returns any other value, the value will be used as the value of the node
and the node itself will be emptied of children.

This will allow use of mapsubtrees for complex use cases.

Suppose you would like to combine the values of a subdirectory with the
function `hcat` and in turn those values using `vcat`, you can use
`mapsubtrees` to accomplish this:

```julia
reducevalues(vcat, mapsubtrees(x->reducevalues(hcat, x), t, glob"*/*"))
```
"""
function mapsubtrees(f, t::FileTree, g::GlobMatch)
    _glob_map(identity, t, name(t), g.pattern...) do match
        x = f(match)
        if !(x isa Union{FileTree, File})
            setvalue(empty(match), x)
        else
            match
        end
    end |> setparent
end

function mapsubtrees(f, t::FileTree, r::Regex)
    _regex_map(identity, t, r) do match
        x = f(match)
        if !(x isa Union{FileTree, File})
            setvalue(empty(match), x)
        else
            match
        end
    end |> setparent
end
