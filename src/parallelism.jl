lazy(f; kw...) = delayed(f; kw...)

# If any input is lazy, make the output lazy
maybe_lazy(f, x) = any(x->x isa Union{Thunk, Chunk}, x) ? lazy(f)(x...) : f(x...)
maybe_lazy(f) = (x...) -> maybe_lazy(f, x)

compute(d::FileTree; cache=true, kw...) = compute(Dagger.Context(), d; cache=cache, kw...)
function compute(ctx, d::FileTree; cache=true, kw...)
    thunks = []
    mapvalues(d; lazy=false) do x
        if x isa Thunk
            if cache
                x.cache = true
            end
            push!(thunks, x)
        end
    end

    vals = compute(delayed((xs...)->[xs...]; meta=true)(thunks...); kw...)

    i = 0
    mapvalues(d; lazy=false) do x
        i += 1
        vals[i]
    end
end

exec(d::FileTree) = mapvalues(exec, compute(d, cache=false); lazy=false)
exec(d::Union{Thunk, Chunk}) = collect(compute(d))
exec(x) = x
