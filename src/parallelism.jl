import Dagger
import Dagger: compute, delayed
export lazy, execute

function lazy(f)
    lazy_mode[] = true
    thing = f()
    lazy_mode[] = false
    thing
end

const lazy_mode = Ref(false)

_modal_apply(f, x...) = lazy_mode[] ? delayed(f)(x...) : f(x...)
<|(f, x) = _modal_apply(f, x)
<|(f) = (x...) -> _modal_apply(f, x...)

function Dagger.compute(ctx, d::FileTree)
    println("here")
    thunks = []
    mapvalues(d) do x
        if x isa Dagger.Thunk
            push!(thunks, x)
        end
    end

    vals = compute(delayed((xs...)->[xs...]; meta=true)(thunks...))

    @show vals

    i = 0
    mapvalues(d) do x
        i += 1
        vals[i]
    end
end

function execute(d::FileTree)
    mapvalues(compute(d)) do x
        x isa Dagger.Chunk ? collect(x) : x
    end
end

execute(d::Union{Dagger.Thunk, Dagger.Chunk}) = collect(d)
