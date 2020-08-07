# DirTools_.jl_ documentation

**DirTools contains tools to lazy-load, process and write file trees.** \\ Built-in parallelism allows you to max out compute on any machine.

There are no restrictions on what files you can read and write. If you have functions to work with one file, you can use the same to work with a file tree.

Lazy tree operations let you freely restructure file trees so as to be convenient to set up computations. Files in a file tree can have any value attached to them (not necessarily those loaded from the file itself), values in these nodes can be combined by merging trees or subtrees.

