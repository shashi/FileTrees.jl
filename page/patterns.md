## Pattern matching paths

Several functions take `String`, `GlobMatch` or `Regex` patterns as arguments.

- `GlobMatch` is provided by the [Glob.jl package](https://github.com/vtjnash/Glob.jl#readme), and can be constructed using `glob""` string macro for example `glob"*/*.jl` means all `.jl` files immediately inside subdirectories.
- `Regex` is created using a the `r""` string macro. The regular expression syntax is detailed in the [Julia documentation](https://docs.julialang.org/en/v1/manual/strings/#Regular-Expressions-1)

Each type of pattern, when used with a function, produces different but memorable behaviors. These are detailed in the following table with some annotations.

In the table

- `t` refers to the tree being operated on
- `p` refers to the pattern of type `T` which is the pattern type.
- "node" means a File or a FileTree.
- ❌ means the pattern type cannot be used with the given function.

| function/T                                 | String                | Glob                     | Regex   |
| ---------------------------|-----------------------|--------------------------|--------------------------|
| `t[p]`                                     | gets node at path  [^1]   | gets subtree of matches [^2] | gets subtree of matches [^2] [^3] |
| `cp(t, r::T, s)` \\ `mv(t, r::T, s)`                | ❌        | ❌                       | move each match to `replace(path(<match>), r => s)`  [^3]        [^4]             |
| `mapmatches(f,t,p::T)`                   | applies `f` to `t[p]` | apply `f` to every match | apply `f` to every match  |
| `mkpath(t,p::T;value)` \\ `touch(t,p::T;value)` | Create a single node at p | ❌                       | ❌                    |
| `mapsubtrees(t,p::T)` | ❌ | For every path in tree (could be non-leaf) which matches `p` fully, apply `f` | ❌                    |

[^1]: the parent of this node is still set to its original parent in `t`. Hence `path(t[p])` will give its full path. But you can do `setparent(t[p], nothing)` to detach it from the original tree.
[^2]: the subtree always has the same root as `t`
[^3]: regex matching string-matches an path string. Partial matches are allowed. surround the regex in `^...$` to match the entire path.
[^4]: `s` here is a `SubstitutionString` and can be created using the [`s""`](https://docs.julialang.org/en/v1/base/strings/#Base.@s_str) string macro (from Base julia).
