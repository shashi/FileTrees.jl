## File path matching

Paths in FileTrees can be matched with patterns. Patterns can be:
- A String. A string always matches a specific file
- A Glob: always refers to the subtree
- A Regex: always refers to the subtree

"node" refers to a File or a FileTree.

-------------------------------------------------------------------------------------------------------
function/T              | String                | Glob                     | Regex                     |
-------------------------------------------------------------------------------------------------------
getindex                | gets node at path     | gets subtree of matches  | gets subtree of matches   |
(cp|mv)(t, r::T, s)     | subtree of matches    | ❌                       | move each match to `replace(path(<match>), r => s)`                       |
mapmatches(f, t, p::T)  | applies `f` to `t[p]` | apply `f` to every match | apply `f` to every match  |
(touch|mkpath)(t, p::T) | Create a single node at p | ❌                       | ❌                    |
