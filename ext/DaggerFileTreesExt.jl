module DaggerFileTreesExt

import FileTrees, Dagger
using FileTrees: FileTree, exec, Thunk, mapvalues

# Submodule to avoid name clash with the actual Dagger module
module Executor

    import Dagger: Options

    struct Dagger{O<:Options}
        options::O
    end
    Dagger() = Dagger(Options())
end

"""
    compute([e], tree::FileTree)

Compute any lazy values (Thunks) in `tree` using executor `e` (default `Executors.Dagger`) and return a new tree where the values refer to
the computed values (maybe on remote processes if applicable). 
    
For executors which compute the lazy values in separate tasks, the returned tree still behaves as a Lazy tree. `exec` on it will fetch the
values.
"""
Dagger.compute(d::FileTree; kw...) = Dagger.compute(Executor.Dagger(), d; kw...)
Dagger.compute(e, d::FileTree; kw...) = mapvalues(v -> exec(e, v, identity), d; lazy=false)

function FileTrees.exec(e::Executor.Dagger, t::Thunk, collect_results=fetch)  
    collect_results(Dagger.spawn(t.f, e.options, map(a -> exec(e, a, identity), t.args)...; (k => exec(e, v, identity) for (k,v) in t.kwargs)...))
end

function __init__() 
    # Make Executor.Dagger from this module visible in FileTrees.Executor
    @eval FileTrees.Executor begin

        """
            Dagger([options])

        Use `Dagger.jl` to to spawn each computation in a separate task using `Dagger.spawn` when provided as first argument to `exec`.
        Options for `Dagger.spawn` can be provided as `options`.
        """
        const Dagger = $(Executor.Dagger)
    end
end


end