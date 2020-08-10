# What is FileTrees?

~~~
<p style="font-size: 1.15em; color: #666; line-height:1.5em">
FileTrees is a set of tools to lazy-load, process and write file trees. Built-in parallelism allows you to max out compute on any machine.
</p>
~~~

Lazy tree operations let you freely restructure file trees so as to be convenient to set up computations. Files in a file tree can have any value attached to them (not necessarily those loaded from the file itself), you can map and reduce over these values, or combine them by merging or collapsing trees or subtrees.

**On this website**

~~~
<ul>
<li><a href="api/">API documentation</a></li>
<li><a href="patterns/">Pattern matching on paths</a></li>
</ul>
~~~

**In this article**
\toc

# Loading directories

The basic datastructure in FileTrees is the [`FileTree`](api/#FileTree) tree. The nodes of this tree can be themselves `FileTree` or `File` objects.

You can read in a directory structure from disk by simply calling `FileTree` with the directory name.

```julia:dir1
using FileTrees

taxi_dir = FileTree("taxi-data")
```

The files in the directory can be loaded using the [`load`](api/#load) function.
Here we will use CSV and DataFrames to load the csv files.

```julia:dir1

using DataFrames, CSV

dfs = FileTrees.load(taxi_dir) do file
    DataFrame(CSV.File(path(file)))
end
```

A summary of the value loaded into each file is shown in parentheses. The `file` argument passed to the load callback is a `File` object. It supports the [`name`](api/#name), [`path`](api/#path) and [`parent`](api/#parent) functions.

`load` returns a new `FileTree` which has the same structure as before, but contains the loaded data in each `File` node.

# Indexing

Let's look at one of these DataFrames by indexing into the tree. The syntax `file[]` on a file object returns the loaded data.

```julia:dir1
yellow_jan_20 = dfs["2020/01/yellow.csv"]

yellow_jan_20[] # file[] gets the value
```

Yellow and Green taxi data have different set of columns. It may be convenient to separate them out into two trees. There are several ways to do this, they are all correct.

```julia:dir1
# method 1

yellow = dfs[glob"*/*/yellow.csv"]
green = dfs[glob"*/*/green.csv"];
```

Here we used a [glob](https://linux.die.net/man/3/glob) expression constructed with the `glob""` string macro. This macro is provided by [Glob.jl](https://github.com/vtjnash/Glob.jl) and is re-exported by FileTrees.

```julia:dir1
# method 2

yellow = dfs[glob"*/*/yellow.csv"]
green = diff(dfs, yellow);
```

[`diff`](api/#diff) allows you to "subtract" a tree structure from another. Here we have only yellow and green taxi files, so diff only leaves the green files behind.

Let's see how they look:

```julia:dir1
# method 3

yellow = dfs[r"yellow.csv$"]
green = diff(dfs, yellow);
```

Here we are indexing the tree with a regular expression. The regular expression in this case matches any path ending with the string "yellow.csv".

All the above methods should return the exact same yellow and green trees:

```julia:dir1
@show yellow
@show green
```

Here is a cool command to restructure the `yellow` tree to have one less level. You can't do this in the shell without a loop, but here we can use regular expressions.


# mv

```julia:dir1
# method 3

yellow′ = mv(dfs, r"(.*)/(.*)/yellow.csv", s"yellow/\1/\2.csv")["yellow"]
green′ = mv(dfs, r"(.*)/(.*)/green.csv", s"green/\1/\2.csv")["green"]

@show yellow′
@show green′
```

`mv` does not affect the file system, it only restructures the tree in memory. But you can save the new structure into disk. Let's write the `yellow` tree to disk, further, let's only save the first 10 columns of the data into these files.


# save

```julia:dir1
FileTrees.save(setparent(yellow′, nothing)) do file
    CSV.write(path(file), file[])
end
```

It's saved!
```julia:dir1
FileTree("yellow")
```

# Reduction

Now that we have files with the same schema in different trees,  we can reduce either tree with `vcat` function on DataFrames to combine the dataframes into a single dataframe:

```julia:dir1
yellowdf = reducevalues(vcat, yellow)

first(yellowdf, 15)
```

# Parallelism and laziness

If `load` is called with `lazy=true` flag, data is not immediately loaded in memory, but a task is created at each file node for loading the file.

Lazy-loading allows you to save precious memory if you're not going to use most of the data. (e.g. If you just want to look at yellow taxi data but you end up loading the whole dataset, it's ok when in lazy mode).

In contrast, in the previous section, `load` without `lazy=true` simply loaded the data one file at a time eagerly.

When you lazy-load and chain operations on the lazy loaded data, you are also telling FileTrees about the dependency of tasks involved in the computation. `mapvalues` or `reducevalues` on lazy-loaded data will themselves return trees with lazy values or a lazy value respectively. To compute lazy values, you can call the `exec` function. This will do the computation in parallel.

```julia:dir1

lazy_dfs = FileTrees.load(taxi_dir; lazy=true) do file
    DataFrame(CSV.File(path(file)))
end
```

```julia:dir1
yellow′ = mv(lazy_dfs, r"(.*)/(.*)/yellow.csv", s"yellow/\1/\2.csv")["yellow"]
```

```julia:dir1
yellowdf = exec(reducevalues(vcat, yellow′))

first(yellowdf, 15)
```

Here calling `exec` computes all the values required to compute the result. This means the green taxi data is never loaded into memory in this particular case.

To obtain parallelism you need to start julia in a parallel way:

```sh
export JULIA_NUM_THREADS=10   # 10 concurrent tasks per process (will use multi-threading)
julia -p 8                    # 8 OS pocesses
```

In the REPL:

```julia:cool
using Distributed, .Threads
@everywhere using FileTrees, CSV, DataFrames

lazy_dfs = FileTrees.load(taxi_dir; lazy=true) do file
    # println("Loading $(path(file)) on $(myid()) on thread $(threadid())")
    DataFrame(CSV.File(path(file)))
end

first(exec(reducevalues(vcat, lazy_dfs[r"yellow.csv$"])), 15)
```

If running in an environment with 8 procs with 10 threads each, 80 tasks will work on them in parallel (they are ultimately scheduled by the OS). Once a task has finished, the data required to execute the task is freed from memory if no longer required by any other task. So in this example, the DataFrames loaded from disk are freed from memory right after they've been reduced with `vcat`.

`reducevalues` performs an associative reduce to aide in the freeing of memory: the first two files are loaded, `vcat` is called on them, and the input dataframes are freed from memory. And then when the next two files have been similarly `vcat`ed, the two resulting values are then `vcat`ed and freed, and so on.

If you wish to compute on more data than you have memory to hold, the following information should help you:

As discussed in this example, there are 80 concurrent tasks at any given time executing a task in the graph. So at any given time, the peak memory usage will be the peak memory usage of 80 of the tasks in the task graph. Hence one can plan how many processes and threads should be started at the beginning of a computation so as to keep the memory usage manageable.

It is also necessary to keep in mind what amount of memory a call to `exec` will produce, since that memory allocation cannot be avoided. This means `reducevalues` where the reduction computes a small value (such as sum or mean) works best.

# Caching

The `compute` function is different from the `exec` function in that, it will compute the results of the tasks in the tree and leave the data on remote processes rather than fetch it to the master process. Calling `compute` on a tree will also cause any subsequent requests to compute the same tasks to be served from a cache memory rather than recomputed.


# Advanced tree manipulation: subtrees

[`mapsubtrees`](api/#mapsubtrees) is a powerful function since it allows you to recursively apply tree operations on subtrees of a tree.

This allows a lot of great functionality. Here is a brief list,

- flatten a tree to be only 2 levels:
    `mapsubtrees(flatten, glob"*/*")`
- collapse the directories at level 3:
    `mapsubtrees(x->clip(x, 1), glob"*/*")`
- reduce 2nd level directories with hcat, but 1st level with `vcat`:
    `reducevalues(vcat, mapsubtrees(x->reducevalues(hcat, x), glob"*"))`
  Note that this will work on lazy trees by creating lazy nodes as well.

Happy Hacking!
