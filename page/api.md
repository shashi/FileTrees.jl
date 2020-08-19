# API documentation

### Data structure

{{doc FileTree FileTree type}}

{{doc File File type}}

{{doc name name function}}

{{doc path path function}}

{{doc parent(::FileTree) parent function}}

{{doc get(::Union{FileTree,File}) get method}}

{{doc rename rename function}}

{{doc setparent setparent function}}

{{doc setvalue setvalue function}}

### Tree manipulation

See the article on [tree manipulation](/tree-manipulation/).

{{doc filter(f, ::FileTree; walk, dirs) map/filter methods}}

{{doc mapsubtrees mapsubtrees method}}

{{doc merge(::FileTree, ::FileTree; combine) merge method}}

{{doc diff(::FileTree, ::FileTree) diff method}}

{{doc mv(::FileTree, ::Regex, ::SubstitutionString; combine) mv method}}

{{doc cp(::FileTree, ::Regex, ::SubstitutionString; combine) cp method}}

{{doc rm(::FileTree, path) rm method}}

### Values in trees

See the article on [values](/values).

{{doc load FileTrees.load function}}

{{doc mapvalues mapvalues function}}

{{doc reducevalues  reducevalues function}}

{{doc save FileTrees.save function}}

### Laziness and Parallelism

{{doc compute(::FileTree; cache; kw...) compute method}}

{{doc exec exec function}}
