# toplevel is an internal flag
function Base.mv(t, from_path::Regex, to_path::SubstitutionString; combine=_merge_error)
    matches, unmatches = detach(t, from_path)
    isempty(matches) && return t

    newtree = maketree([])
    for x in Leaves(matches)
        newname = replace(path(x), from_path => to_path)
        newtree = attach(newtree, dirname(newname), rename(x, basename(newname)); combine=combine)
    end
    merge(unmatches, newtree; combine=combine)
end

function Base.cp(t, from_path::Regex, to_path::SubstitutionString; combine=_merge_error)
    matches = t[from_path]
    isempty(matches) && return t

    newtree = maketree([])
    for x in Leaves(matches)
        newname = replace(path(x), from_path => to_path)
        newtree = attach(newtree, dirname(newname), rename(x, basename(newname)); combine=combine)
    end
    merge(t, newtree; combine=combine)
end

function Base.rm(t, path)
    _, t1 = detach(t, path)
    return t1
end

function _mknode(T, t, path::AbstractString)
    spath = splitpath(path)
    subdir = if T == File
        T(nothing, spath[end], NoValue())
    else
        T(nothing, spath[end], [], NoValue())
    end

    if length(spath) == 1
        merge(t, maketree(name(t) => [subdir]))
    else
        p = joinpath(spath[1:end-1]...)
        attach(t, p, subdir)
    end
end

Base.touch(t, path::AbstractString) = _mknode(File, t, path)
Base.mkpath(t, path::AbstractString) = _mknode(FileTree, t, path)
