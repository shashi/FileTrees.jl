# API documentation

### Tree manipulation

{{doc FileTree FileTree type}}

{{doc cp(::FileTree, ::Regex, ::SubstitutionString; combine) cp method}}

{{doc cp(::FileTree, ::FileTree; combine) rm method}}

{{doc rm(::FileTree, path) rm method}}

{{doc rm(::FileTree, ::FileTree) rm method}}

{{doc mv(::FileTree, ::Regex, ::SubstitutionString; combine) mv method}}

{{doc mapsubtrees mapsubtrees method}}

### Loading, computing and saving data


{{doc load load function}}

{{doc mapvalues mapvalues function}}

{{doc reducevalues  reducevalues function}}

{{doc save save function}}

### Laziness and Parallelism

{{doc compute(::FileTree; cache; kw...) compute method}}

{{doc exec exec function}}
