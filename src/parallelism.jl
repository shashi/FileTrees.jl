
# Types left off since this is what Dagger does, probably for inference reasons. Not sure if this is the best performance here...
struct Thunk
    f
    args
    kwargs
end

lazy(f) = (args...; kwargs...) -> Thunk(f, args, kwargs)

# If any input is lazy, make the output lazy
maybe_lazy(f, x) = any(x->x isa Thunk, x) ? lazy(f)(x...) : f(x...)

maybe_lazy(f) = (x...) -> maybe_lazy(f, x)

"""
    compute(tree::FileTree; cache=true)

Compute any lazy values (Thunks) in `tree` and return a new tree where the values refer to
the computed values (maybe on remote processes). The tree still behaves as a Lazy tree. `exec` on it will fetch the values from remote processes.
"""
compute(d::FileTree; cache=true, kw...) = compute(Dagger.Context(), d; cache=cache, kw...)
compute(ctx, d::FileTree; cache=true, kw...) = mapvalues(v -> exec(ctx, v, identity), d; lazy=false)

"""
    exec(x)

If `x` is a `FileTree`, computes any uncomputed `Thunk`s stored as values in it. Returns a new tree with the computed values.
If `x` is a `File`, computes the value if it is a `Thunk`. Returns a new `File` with the computed value.
If `x` is a `Thunk` (such as the result of a `reducevalues`), then exec will compute the result.
If `x` is anything else, `exec` just returns the same value.
"""
exec(x) = exec(Dagger.Context(), x)

"""
    exec(ctx, x)

Same as `exec(x)` with a ctx being passed to `Dagger` when computing any `Thunks`.
"""
exec(ctx, x, args...) = x

exec(ctx, d::FileTree, args...) = mapvalues(fetch, compute(ctx, d))
exec(ctx, f::File, collect_results=fetch) = setvalue(f, exec(ctx, f[], collect_results))

# TODO: Probably need to rework this since there does not seem to be a (safe) way to set the context for a spawned task (context seems to be global since scheduler is global)?
exec(ctx::Dagger.Context, t::Thunk, collect_results=fetch) = collect_results(Dagger.spawn(t.f, map(a -> exec(ctx, a, identity), t.args)...; (k => exec(ctx, v, identity) for (k,v) in t.kwargs)...))

# TODO: Not sure if these are worth keeping. Added mostly for benchmarking reasons
struct SingleTreadedContext end
exec(ctx::SingleTreadedContext, t::Thunk, args...) = t.f(map(a -> exec(ctx, a), t.args)...; (k => exec(ctx, v) for (k,v) in t.kwargs)...)

struct ThreadContext end
function exec(ctx::ThreadContext, t::Thunk, collect_results=fetch) 
    args = map(a -> exec(ctx, a, identity), t.args) 
    kwargs = [k => exec(ctx, v, identity) for (k,v) in t.kwargs]
    res = Threads.@spawn t.f(map(fetch, args)...; (k => fetch(v) for (k,v) in kwargs)...)
    collect_results(res)
end
 