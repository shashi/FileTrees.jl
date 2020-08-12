
# Values in file trees

\blurb{And how to work with them.}

Files and subtrees in a FileTree can have [any value attached to them](#loading-values) (not necessarily those loaded from the file itself), you can map and reduce over these values using [`mapvalues`](#mapvalues) and [`reducevalues`](#reducevalues), or combine them by merging with other trees or [collapsing subtrees](#mapsubtrees_value_operations).

All these operations will be lazy if files are loaded lazily. Calling [`exec`](/api/#exec), [`compute`](/api/#compute) or [`save`](/api/#save) on a lazy value or tree with lazy values will cause the dependent values to be loaded and computed.

## Loading values

[`FileTrees.load`](/api/#load) can be used to load values into a tree.

```julia:dir1
using DataFrames, CSV, FileTrees

taxi_dir = FileTree("taxi-data")

dfs = FileTrees.load(taxi_dir) do file
    DataFrame(CSV.File(path(file)))
end
```

It's probably obvious, but you can load any file type and even values that have nothing to do with the file.

Loading can be made lazy using the `lazy=true` flag. More on laziness [here](/lazy-parallel/).
```julia:dir1
lazy_dfs = FileTrees.load(taxi_dir; lazy=true) do file
    DataFrame(CSV.File(path(file)))
end
```
Below we will see the effect of each value-manipulating function when called with both lazy and non-lazy trees.

## mapvalues

`mapvalues(f, t::FileTree)` applies `f` to every node in `t` which has a value loaded into it. It returns a new tree with the resultant values in place of the original ones.

Let's drop all but the first 5 columns of the dataframes we have loaded:
```julia:dir1
small_dfs = mapvalues(df->df[:, 1:5], dfs)
```

mapvalues on a lazy tree creates a lazy tree, where the values on `exec` will be the right computed values.
```julia:dir1
small_dfs_lazy = mapvalues(df->df[:, 1:5], lazy_dfs)
```
This map function should be instantaneous since it does not actually carry out the computation, instead returns a tree with lazy tasks that need to be carried out.

`exec` will materialize these values:

```julia:dir1
exec(small_dfs_lazy)
```
## reducevalues

`reducevalues(f, t::FileTree)` reduce all nodes in `t` into a single value by successively applying `f`. `f` is assumed to be [associative](https://en.wikipedia.org/wiki/Associative_property) and an ordering that is optimal for parallelism is chosen. If `f` is not `associative`, pass `associative=false` keyword argument.

```julia:dir1
first(reducevalues(vcat, small_dfs[r"yellow.csv$"]), 12)
```
```julia:dir1
reducevalues(vcat, small_dfs_lazy[r"yellow.csv$"])
```

This returned a delayed task that to compute the result. `exec` will compute it:

```julia:dir1
first(exec(reducevalues(vcat, small_dfs_lazy[r"yellow.csv$"])), 12)
```

## mapsubtrees + value operations

[`mapsubtrees`](/api/#mapsubtrees) is a powerful function since it allows you to recursively apply tree operations on subtrees of a tree.

See [more about it here](/tree-manipulation/#mapsubtrees).
