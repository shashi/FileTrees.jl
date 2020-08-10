# Values in file trees

And how to work with them.

## loading values

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
mapvalues(df->df[:, 1:5], dfs)
```

mapvalues on a lazy tree creates a lazy tree, where the values on `exec` will be the right computed values.
```julia:dir1
mapvalues(df->df[:, 1:5], lazy_dfs)
```

```julia:dir1
exec(mapvalues(df->df[:, 1:5], lazy_dfs))
```
## reducevalues

`reducevalues(f, t::FileTree)` reduce all nodes in `t` into a single value by successively applying `f`. `f` is assumed to be [associative](https://en.wikipedia.org/wiki/Associative_property) and an ordering that is optimal for parallelism is chosen. If `f` is not `associative`, pass `associative=false` keyword argument.

Let's use reducevalues to combine the yellow.csv 5-column dataframes.

```julia:dir1
mapvalues(df->df[:, 1:5], dfs[r"yellow.csv$"])
```

mapvalues on a lazy tree creates a lazy tree, where the values on `exec` will be the right computed values.
```julia:dir1
mapvalues(df->df[:, 1:5], lazy_dfs)
```

```julia:dir1
exec(mapvalues(df->df[:, 1:5], lazy_dfs))
```

## mapsubtrees + value operations
