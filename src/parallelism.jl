lazy(f; kw...) = delayed(f; kw...)

# If any input is lazy, make the output lazy
maybe_lazy(f, x) = any(x->x isa Union{Thunk, Chunk}, x) ? lazy(f)(x...) : f(x...)

maybe_lazy(f) = (x...) -> maybe_lazy(f, x)

function mapcompute(ctx, xs;
                    cache=false,
                    collect_results=identity,
                    map=map, kw...)

    # Dagger does not have a way to just say "here is a bunch of Thunks, just compute them for me please"
    # To make Dagger do this for us, we collect all Thunks in xs and ask Dagger to concatenate them into an array
    # Once we have that array we just put the computed values back at the same place we found them
    # Note that we rely on map visiting all elements in the same order each time it is called

    # Creating all these intermediate arrys do have a little bit of overhead and I doubt this
    # is the most efficient way of doing it. Hopefully if people end up here it is because they
    # actually have heavy computations where the extra overhead is not significant

    # Step 1: Collect  all thunks in xs
    thunks = Thunk[]
    map(xs) do x
        if x isa Thunk
            if cache
                x.cache = true
            end
            push!(thunks, x)
        end
        x
    end

    # Step 2: Ask Dagger to concatenate the results into vals
    # We do assocreduce here mainly to prevent inference issues when xs is heterogenous
    # Drawback vs e.g. splatting the whole array into a single delayed call to vcat is 
    # that we end up creating a fair bit of intermediate arrays (about log2(length(thunks))).
    vals = collect_results(compute(ctx, assocreduce(delayed(vcat; meta=true), thunks); kw...))

    # Step 3: Put the computed results back at the same places we found them
    # This is where we rely on map visiting all elements in the same order.
    i = 0
    map(xs) do x
        # Expression returns vals[i] or x
        if x isa Thunk
            i += 1
            vals[i]
        else
            x
        end
    end
end

function mapexec(ctx, xs; cache=false, map=map)
    mapcompute(ctx, xs;
               map=map,
               cache=cache,
               collect_results=xs -> collect_chunks(ctx, xs))
end

collect_chunks(ctx, x) = [exec(ctx,x)]
collect_chunks(ctx, xs::AbstractArray) = asyncmap(d -> exec(ctx,d), xs)

"""
    compute(tree::FileTree; cache=true)

Compute any lazy values (Thunks) in `tree` and return a new tree where the values refer to
the computed values (maybe on remote processes). The tree still behaves as a Lazy tree. `exec` on it will fetch the values from remote processes.
"""
compute(d::FileTree; cache=true, kw...) = compute(Dagger.Context(), d; cache=cache, kw...)

function compute(ctx, d::FileTree; cache=true, kw...)
    mapcompute(ctx, d, map=((f,t) -> mapvalues(f, t; lazy=false)), cache=cache; kw...)
end

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
exec(ctx, x) = x

exec(ctx, d::FileTree) = mapexec(ctx, d, map=(f,t) -> mapvalues(f, t; lazy=false))
exec(ctx, f::File) = setvalue(f, exec(ctx, f[]))

exec(ctx, d::Union{Thunk, Chunk}) = collect(ctx, compute(ctx, d))
