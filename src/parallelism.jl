import Dagger
import Dagger: compute, delayed
export lazy, exec

struct Lazy
    f
    args::Tuple
end

dag(x) = x
dag(l::Lazy) = delayed(l.f)(map(dag, l.args)...)

compute(ctx, l::Lazy) = compute(dag(l))

function Base.show(io::IO, z::Lazy)
    lvl = get(io, :lazy_level, 1)
    print(io, "Lazy($(z.f), ")
    if lvl < 2
        show(IOContext(io, :lazy_level => lvl+1), z.args)
    else
        print(io, "...")
    end
    print(io, ")")
end

lazy(f; kw...) = (x...) -> Lazy(f, x; kw...)

# If any input is Lazy, make the output Lazy
_lazy_if_lazy(f, x...) = any(x->x isa Lazy, x) ? lazy(f)(x...) : f(x...)
_lazy_if_lazy(f) = (x...) -> _lazy_if_lazy(f, x...)

function compute(ctx, d::FileTree)
    println("here")
    thunks = []
    mapvalues(d) do x
        if x isa Dagger.Thunk
            push!(thunks, x)
        elseif x isa Lazy
            push!(thunks, dag(x))
        end
    end

    vals = compute(delayed((xs...)->[xs...]; meta=true)(thunks...))

    i = 0
    mapvalues(d) do x
        i += 1
        vals[i]
    end
end

function exec(d::FileTree)
    mapvalues(compute(d)) do x
        x isa Dagger.Chunk ? collect(x) : x
    end
end

exec(d::Union{Lazy, Dagger.Thunk, Dagger.Chunk}) = collect(compute(d))

exec(x) = x
