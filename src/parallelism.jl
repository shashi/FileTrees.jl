using Dagger
export compute, par_exec

function Dagger.compute(ctx, d::DirTree)
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

function par_exec(d::DirTree)
    mapvalues(compute(d)) do x
        x isa Dagger.Chunk ? collect(x) : x
    end
end
