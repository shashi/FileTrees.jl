module FileTrees

using AbstractTrees
import AbstractTrees: children
import Base: parent, getindex

export FileTree, File, name, path, maketree, children, rename, setvalue, setparent

include("datastructure.jl")


import Base: cp, mv, rm, touch, mkpath

include("fs.jl")


import Glob: GlobMatch, @glob_str

export @glob_str
export mapsubtrees

include("patterns.jl")


export mapvalues, reducevalues, NoValue, hasvalue # load, save

include("values.jl")


import Dagger
import Dagger: compute, delayed, Chunk, Thunk

export lazy, exec, compute

include("parallelism.jl")

end # module

