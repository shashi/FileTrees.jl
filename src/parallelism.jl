import Dagger
import Dagger: compute
export lazy, execute

function lazy(f)
    lazy_mode[] = true
    thing = f()
    lazy_mode[] = false
    thing
end

const lazy_mode = Ref(false)

_modal_apply(f, x...) = lazy_mode[] ? delayed(f)(x...) : f(x...)
<|(f, x) = _modal_apply(x...)
<|(f) = (x...) -> _modal_exec(f, x...)

function Dagger.compute(ctx, d::FileTree)
    thunks = []
    mapvalues(d) do x
        if x isa Thunk
            push!(thunks, x)
        end
    end

    vals = compute(delayed((xs...)->[xs...]; meta=true)(thunks...))

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
