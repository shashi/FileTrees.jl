# What is DirTools?

~~~
<p style="font-size: 1.15em; color: #666; line-height:1.5em">
DirTools is a set of tools to lazy-load, process and write file trees. Built-in parallelism allows you to max out compute on any machine.
</p>
~~~

There are no restrictions on what files you can read and write. If you have functions to work with one file, you can use the same to work with a file tree.

Lazy tree operations let you freely restructure file trees so as to be convenient to set up computations. Files in a file tree can have any value attached to them (not necessarily those loaded from the file itself), you can map and reduce over these values, or combine them by merging or collapsing trees or subtrees.

## Introduction

The basic datastructure in DirTools is the `Dir` tree. The nodes of this tree can be themselves `Dir` or `File` objects. Each node contains a `name` field which shows its name.

```julia:dir1
using DirTools

taxi_dir = Dir("taxi-data")
```

The files in the directory can be loaded using the `load` function. Here we use CSV and DataFrames to load the csv files.

```julia:dir1

using DataFrames, CSV

dfs = DirTools.load(taxi_dir) do file
    DataFrame(CSV.File(path(file)))
end
```

`load` takes a callback which loads a single file. The `file` argument to the callback is a `File` object. It supports the `path`, `parent` and `value` functions.

`load` returns a new `Dir` which has the same structure as before, but contains the loaded data in each `File` node.


A summary of the value loaded into each file is shown in parentheses. Let's look at one of these DataFrames by indexing into the tree and calling `value` on the file.

```julia:dir1
using DirTools: value # hide
value(dfs["2020/01/yellow.csv"])
```

We may want to combine all yellow taxi files into a single DataFrame using `reducevalues`.

But first, we have to separate them out. There are several ways to do this, they are all correct.

```julia:dir1
# method 1

yellow = dfs[glob"*/*/yellow.csv"]
green = dfs[glob"*/*/green.csv"]

# method 2

yellow = dfs[glob"*/*/yellow.csv"]
green = DirTools.treediff(dfs, yellow);

@show yellow
@show green
```

Here is a cool command to restructure the `yellow` tree to have one less level. You can't do this in the shell without a loop, but here we can use regular expressions.

```julia:dir1
# method 3

yellow′ = mv(dfs, r"(.*)/(.*)/yellow.csv", s"yellow/\1/\2.csv")["yellow"]
green′ = mv(dfs, r"(.*)/(.*)/green.csv", s"green/\1/\2.csv")["green"]

@show yellow′
@show green′
```

`mv` does not affect the file system, it only restructures the tree in memory. But you can save the new structure into disk. Let's write the `yellow` tree to disk, further, let's only save the first 10 columns of the data into these files.

```julia:dir1
DirTools.save(DirTools.set_parent(yellow′, nothing)) do file
    CSV.write(path(file), value(file))
end
```

It's saved!
```julia:dir1
Dir("yellow")
```

Coming back to our original goal, we can combine the yellow tree into a single DataFrame:

```julia:dir1
yellowdf = reducevalues(vcat, yellow)

first(yellowdf, 15)
```

## Parallelism and laziness

In the previous section, `load` simply loaded the data into memory when called, this does not happen in parallel by default. The way to load files in parallel is to load them with the `lazy=true` flag. This creates lazy tree of computations (called `Thunk`s). Any subsequent `mapvalues` or `reducevalues` will be lazy if called on a lazy-loaded tree. At any point to materialize lazy values, you can call the `exec` function.


```julia:dir1

lazy_dfs = DirTools.load(taxi_dir; lazy=true) do file
    DataFrame(CSV.File(path(file)))
end
```

Great thing about it is you can still filter the tree or restructure it.

```julia:dir1
yellow′ = mv(lazy_dfs, r"(.*)/(.*)/yellow.csv", s"yellow/\1/\2.csv")["yellow"]
```
tree restructuring keeps the values lazy.

```julia:dir1
yellowdf = exec(reducevalues(vcat, yellow′))

first(yellowdf, 15)
```

Here calling `exec` is computes all the values required to compute the result.

This computation is set up to be parallel:

To obtain parallelism you need to start julia in a parallel way:

```sh
export JULIA_NUM_THREADS=10   # 10 concurrent tasks per process (will use multi-threading)
julia -p 8                    # 8 OS pocesses
```

In the REPL:

```julia
@everywhere using DirTools, CSV, DataFrames

lazy_dfs = DirTools.load(taxi_dir; lazy=true) do file
    DataFrame(CSV.File(path(file)))
end

reduce(vcat, lazy_dfs) |> exec;
```

Here at most 10x8 files are loaded at a time into memory. And 80 tasks will work on them in parallel as the OS is able to schedule them. these 80 files are first reduced using the reduction function and then DirTools will move on to the next 80 files while releasing the first 80 from memory. This is very beneficial if you have 1000s of files.

Happy Hacking!
