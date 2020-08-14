lazy(f; kw...) = delayed(f; kw...)

# If any input is lazy, make the output lazy
maybe_lazy(f, x) = any(x->x isa Union{Thunk, Chunk}, x) ? lazy(f)(x...) : f(x...)

maybe_lazy(f) = (x...) -> maybe_lazy(f, x)

function mapcompute(xs;
                    cache=false,
                    collect_results=identity,
                    map=map, kw...)
    thunks = []
    map(xs) do x
        if x isa Thunk
            if cache
                x.cache = true
            end
            push!(thunks, x)
        end
        x
    end

    vals = collect_results(compute(delayed((xs...)->[xs...]; meta=true)(thunks...); kw...))

    i = 0
    map(xs) do x
        if x isa Thunk
            i += 1
            vals[i]
        else
            x
        end
    end
end

function mapexec(xs; cache=false, map=map)
    mapcompute(xs;
               map=map,
               cache=cache,
               collect_results=xs -> asyncmap(exec, xs))
end


"""
    compute(tree::FileTree; cache=true)

Compute any lazy values (Thunks) in `tree` and return a new tree where the values refer to
the computed values (maybe on remote processes). The tree still behaves as a Lazy tree. `exec` on it will fetch the values from remote processes.
"""
compute(d::FileTree; cache=true, kw...) = compute(Dagger.Context(), d; cache=cache, kw...)

function compute(ctx, d::FileTree; cache=true, kw...)
    mapcompute(d, map=((f,t) -> mapvalues(f, t; lazy=false)), cache=cache; kw...)
end

"""
    exec(x)

If `x` is a FileTree, computes any uncomputed `Thunk`s stored as values in it. Returns a new tree with the computed values.
If `x` is a `Thunk` (such as the result of a `reducevalues`), then exec will compute the result.
If `x` is anything else, `exec` just returns the same value.
"""
exec(x) = x

exec(d::FileTree) = mapexec(d, map=(f,t) -> mapvalues(f, t; lazy=false))

exec(d::Union{Thunk, Chunk}) = collect(compute(d))
