~~~
<h1>FileTrees.jl &mdash; overview</h1>
~~~

\blurb{
FileTrees is a set of tools to lazy-load, process and save file trees.
Built-in parallelism allows you to max out all threads and processes that Julia is running with.}

Files and subtrees in a file tree can have any [value attached to them](/values/), you can map and reduce over these values, or combine them by merging or collapsing trees or subtrees. When computing [lazy](/lazy-parallel/) trees, these values are held in distributed memory and operated on in parallel.

Tree operations such as [`map`, `filter`](/api/#map/filter), [`mv`](/api/#mv), [`merge`](/api/#merge), [`diff`](/api/#merge) are immutable. Nothing is written to disk until [`save`](/api/#save) is called to save a tree, hence tree restructuring is cheap and fast.

**Getting started**

You can install FileTrees with:

```julia
using Pkg
Pkg.add("https://github.com/shashi/FileTrees.jl")
```

In this article we will see how to load a directory of files, do something to them, and then combine the results. This should help you get started!

You can navigate to `page/` folder under the FileTrees package directory to try this out for yourself with the sample data there. Or you can try it with your own directory of data files!

\toc

# Loading directories

The basic datastructure in FileTrees is the [`FileTree`](api/#FileTree).

Calling `FileTree` with a directory name will walk the directory on disk and construct a `FileTree`. Here we have a tiny sampling of data from the [NYC Taxi dataset](https://www1.nyc.gov/site/tlc/about/tlc-trip-record-data.page), for January and February of 2019 and 2020. Let's read the FileTree from this directory:

```julia:dir1
using FileTrees

taxi_dir = FileTree("taxi-data")
```

The files in the directory can be loaded using the [`load`](api/#load) function. Here we will use CSV and DataFrames to load the csv files.

```julia:dir1

using DataFrames, CSV

dfs = FileTrees.load(taxi_dir) do file
    DataFrame(CSV.File(path(file)))
end
```

A summary of the value loaded into each file is shown in parentheses. The `file` argument passed to the load callback is a `File` object. It supports the [`name`](api/#name), [`path`](api/#path) function among others. `path` returns an [`AbstractPath`](https://rofinn.github.io/FilePathsBase.jl/stable/api/#FilePathsBase.AbstractPath) which refers to the file's location.

`load` returns a new `FileTree` which has the same structure as before, but contains the loaded data in each `File` node.

Here `load` actually read the files eagerly. This may not be desirable if the data to be loaded are too big to fit in memory, or you don't intend to use all of it, but only a subtree of it.

In such a case, you can load the files lazily using `lazy=true`

```julia:dir1
lazy_dfs = FileTrees.load(taxi_dir; lazy=true) do file
    DataFrame(CSV.File(path(file)))
end
```

As you can see the nodes have `Thunk` objects -- this represents a lazy task that can later be executed using the [`exec`](api/#exec) function. You can continue to use most of the functions in this package without worrying about whether the input tree has lazy values or not. You will get the corresponding lazy outputs wherever the input trees had lazy values. Lazy values also encode dependency between them, hence making it possible for `exec` to compute them in parallel.


See [this article](/values/) to learn more about how to work with values.
To know more details about the usage of laziness and parallelism, go to [this article](lazy-parallel/).

# Looking files up

Let's look at one of these DataFrames by indexing into the tree with the path to a file, namely `"2020/01/yellow.csv"`.

```julia:dir1
yellow_jan_20 = dfs["2020/01/yellow.csv"]
```

`get(file)` fetches the value stored in a `File` or `FileTree` node:

```julia:dir1
get(yellow_jan_20)
```

When a tree is lazy, the `get` operation returns a `Thunk`, a delayed computation.

You can call `exec` on the this value to compute and fetch the value.


```julia:dir1
val = get(lazy_dfs["2020/01/yellow.csv"])

@show typeof(val)
@show exec(val);
```

Yellow and Green taxi data have different set of columns. It may be convenient to separate them out into two trees:

```julia:dir1
yellow = dfs[glob"*/*/yellow.csv"]
green = dfs[glob"*/*/green.csv"];

[yellow green]
```

Here we used a [glob](https://linux.die.net/man/3/glob) expression constructed with the `glob""` string macro. This macro is provided by [Glob.jl](https://github.com/vtjnash/Glob.jl) and is re-exported by FileTrees.

See the [pattern matching](patterns/) documentation to learn more about how to use pattern matching to manipulate trees.

# Combining loaded data

Now that we have files with the same schema in different trees,  we can reduce either tree with `vcat` function on DataFrames to combine the dataframes into a single dataframe:

```julia:dir1
yellowdf = reducevalues(vcat, yellow)

first(yellowdf, 15)
```

`reducevalues` also works on the lazy tree but returns a lazy final result. You can call `exec` on it to actually compute it. This causes the computation to occur in parallel!

```julia:dir1
yellowdf = exec(reducevalues(vcat, lazy_dfs[glob"*/*/yellow.csv"]))

first(yellowdf, 15)
```

Note that in the lazy case the green csv files are never loaded since they are not required to compute the final result!


# Saving to a directory

```julia:dir1
df1 = dfs[glob"*/*/yellow.csv"]

# this mv moves X/Y/yellow.csv to yellow/X/Y.csv
# see the Tree manipulation section of the docs for more

df2 = mv(df1, r"^([^/]*)/([^/]*)/yellow.csv$",
              s"yellow/\1/\2.csv")["yellow"]

@show df2

FileTrees.save(setparent(df2, nothing)) do file
    CSV.write(path(file), get(file))
end
```

It's saved!
```julia:dir1
# let's read back the new directory
FileTree("yellow")
```

```julia:dir1
rm("yellow", recursive=true) # hide
```

Happy Hacking!


Next: **More on [values in trees &rarr;](/values/)**
