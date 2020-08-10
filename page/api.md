# API documentation

### Tree manipulation

{{doc FileTree FileTree type}}

{{doc mv(::FileTree, ::Regex, ::SubstitutionString; combine) mv method}}

{{doc cp(::FileTree, ::Regex, ::SubstitutionString; combine) cp method}}

{{doc rm(::FileTree, path) rm method}}

{{doc merge(::FileTree, ::FileTree; combine) merge method}}

{{doc diff(::FileTree, ::FileTree) diff method}}

{{doc mapsubtrees mapsubtrees method}}

### Loading, computing and saving data


{{doc load load function}}

{{doc mapvalues mapvalues function}}

{{doc reducevalues  reducevalues function}}

{{doc save save function}}

### Laziness and Parallelism

{{doc exec exec function}}
