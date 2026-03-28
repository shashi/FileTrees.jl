
# Types left off since this is what Dagger does, probably for inference reasons. Not sure if this is the best performance here...
struct Thunk
    f
    args
    kwargs
end

lazy(f) = (args...; kwargs...) -> Thunk(f, args, kwargs)

# If any input is lazy, make the output lazy
function _maybe_lazy(f, args, kwargs) 
    if (any(x->x isa Thunk, args) || any(x->x isa Thunk, values(kwargs))) 
        Thunk(f, args, kwargs) 
    else
        f(args...; kwargs...)
    end
end

maybe_lazy(f) = (args...; kwargs...) -> _maybe_lazy(f, args, kwargs)
maybe_lazy(f, args...; kwargs...) = _maybe_lazy(f, args, kwargs)

"""
    exec([e], x)

Return the result of executing `x` using executor `e` (default `Executor.Threads`).

Available executors can be found in the `Executor` submodule.

If `x` is a `FileTree`, computes any uncomputed `Thunk`s stored as values in it. Returns a new tree with the computed values.
If `x` is a `File`, computes the value if it is a `Thunk`. Returns a new `File` with the computed value.
If `x` is a `Thunk` (such as the result of a `reducevalues`), then exec will compute the result.
If `x` is anything else, `exec` just returns the same value.
"""
exec(x) = exec(DEFAULT_EXEC_CONTEXT[], x)
exec(e, x, args...) = x

exec(e, d::FileTree, args...) = mapvalues(fetch, mapvalues(v -> exec(e, v, identity), d; lazy=false))
exec(e, f::File, collect_results=fetch) = setvalue(f, exec(e, f[], collect_results))

struct UnwrappedTaskException{E} <: Exception
    cnt::Int
    msg::String
    stack::E
end

function Base.showerror(io::IO, e::UnwrappedTaskException)
    println(io, e.cnt, " nested TaskFailedExceptions have been unwrapped by FileTrees to reduce clutter!\n",  e.msg)
    for (wrapped, bt) in Iterators.reverse(e.stack)
        showerror(io, wrapped, bt; backtrace=bt !== nothing)
    end
end

fetch_unwrap_exception(t) = try
    fetch(t)
catch e
    if e isa TaskFailedException
        lastthrown = first(current_exceptions(t)).exception
        if lastthrown isa UnwrappedTaskException
            rethrow(UnwrappedTaskException(lastthrown.cnt + 1, lastthrown.msg, lastthrown.stack))
        end
        # kept msg in case other executors also want to unwrap
        rethrow(UnwrappedTaskException(1, "See Executor.Threads documentation for how to disable unwrapping case anything appears to be missing.", current_exceptions(t)))
    end
    rethrow(e)
end

"""
    Executor

Namespace for executor strategies which can be passed as first argument to `exec`.

Executor strategies from extension packages (e.g. Dagger) will also appear here 
when the corresponding package is loaded. 
"""
baremodule Executor

    import ..FileTrees: fetch_unwrap_exception
    using Base: fetch

    # We export these mainly so that help does not warn that they are internal. 
    # Could have used the public keyword, but then we must limit to Julia 1.11?
    export CurrentTask, Threads

    """
        CurrentTask()

    Execute in the current task without spawning any new tasks when passed as first argument to `exec`. 
    
    Useful when minimal overhead is preferred over parallelism.
    """
    struct CurrentTask end

    """
        Threads(;[unwrap_exceptions], [pool])

    Use Julia's standard library `Threads` to spawn each computation in a separate task when passed as first argument to `exec`.

    If the keyword argument `unwrap_exceptions` is set to `true`` (the default), any `TaskFailedExceptions` will be unwrapped,
    which typically results in less visual noise in case the computation throws an exception.
    
    The keyword argument `pool` (default `:default`) is given as first argument to `Threads.@spawn`. 
    """
    struct Threads{F}
        pool::Symbol
        collect_results::F
    end
    Threads(;unwrap_exceptions=true, pool=:default) = Threads(pool, unwrap_exceptions ? fetch_unwrap_exception : fetch)
end

const DEFAULT_EXEC_CONTEXT = Ref{Any}(Executor.Threads())

exec(e::Executor.CurrentTask, t::Thunk, args...) = t.f(map(a -> exec(e, a), t.args)...; (k => exec(e, v) for (k,v) in t.kwargs)...)

function exec(e::Executor.Threads, t::Thunk, collect_results=e.collect_results) 
    args = map(a -> exec(e, a, identity), t.args) 
    kwargs = [k => exec(e, v, identity) for (k,v) in t.kwargs]
    res = Threads.@spawn e.pool t.f(map(e.collect_results, args)...; (k => e.collect_results(v) for (k,v) in kwargs)...)
    collect_results(res)
end








