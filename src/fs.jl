function Base.mv(t, from_path, to_path; combine=_merge_error)
end

function Base.cp(t, from_path, to_path; combine=_merge_error)
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
