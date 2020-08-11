module FileTrees

using FilePathsBase
using AbstractTrees
import AbstractTrees: children
import Base: parent, getindex

export FileTree, File, name, path, maketree, children, rename, setvalue, setparent

import FilePathsBase: /, Path, @p_str
export @p_str

include("datastructure.jl")


import Base: cp, mv, rm, touch, mkpath

include("tree-ops.jl")


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

