# Splitting a file into many files


You can "splat" multiple files into a tree by returning `maketree("." => fs)`. This will place the files `fs` in the same directory as the file it replaces.

In `map` or `mapsubtrees` you can use `maketree("." => fs)` where `fs` is a vector to "splat" files into multiple files.

A convenience function will come in handy:
```julia:dir1
splatfiles(fs) = maketree("." => fs)
```


```julia:dir1

using FileTrees
using DataFrames, CSV

taxi_dir = FileTree("taxi-data")

dfs = FileTrees.load(taxi_dir) do file
    DataFrame(CSV.File(path(file)))
end
```

Split up each yellow file into multiple files:

```julia:dir1
yellowdfs = dfs[r"yellow.csv$"]

expanded_tree = mapsubtrees(yellowdfs, glob"*/*/yellow.csv") do df
    map(groupby(get(df), :RatecodeID) |> collect) do group
        (name=string("yellow-ratecode-", group.RatecodeID[1], ".df"), value=DataFrame(group))
    end |> splatfiles
end
```

You can save these files if you wish.

## How to create lazy subtrees?

If the `value` field of a file passed to `splatfiles` is a `Thunk`, then it becomes a lazy value.

A thunk can be created with the syntax `lazy(f)(x...)`. where the result is a `Thunk` which represents the result of executing `f(x...)`.

```julia:dir1
yellowdfs = dfs[r"yellow.csv$"]

expanded_tree = mapsubtrees(yellowdfs, glob"*/*/yellow.csv") do df
    map(groupby(get(df), :payment_type) |> collect) do group
        id = group.payment_type[1]
        (name=string("yellow-ptype-", group.payment_type[1], ".df"), value=lazy(repr)(group))
    end |> splatfiles
end
```

```julia:dir1
exec(expanded_tree)
```

```julia:dir1
exec(expanded_tree) |> files |> first |> get |> print
```
