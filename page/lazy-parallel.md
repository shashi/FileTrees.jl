# Laziness and parallelism

If `load` is called with `lazy=true` flag, data is not immediately loaded in memory, but a task is created at each file node for loading the file.

In contrast, `load` without `lazy=true` simply loads the data one file at a time eagerly.

Lazy-loading allows you to save precious memory if you're not going to use most of the data. (e.g. If you just want to look at yellow taxi data but you end up loading the whole dataset, it's ok when in lazy mode).

When you lazy-load and chain operations on the lazy loaded data, you are also telling FileTrees about the dependency of tasks involved in the computation. `mapvalues` or `reducevalues` on lazy-loaded data will themselves return trees with lazy values or a lazy value respectively. To compute lazy values, you can call the `exec` function. This will do the computation in parallel.

```julia:dir1
using Distributed # for @everywhere
@everywhere using FileTrees
@everywhere using DataFrames, CSV

taxi_dir = FileTree("taxi-data")

lazy_dfs = FileTrees.load(taxi_dir; lazy=true) do file
    DataFrame(CSV.File(path(file)))
end
```

```julia:dir1
yellow′ = mv(lazy_dfs,
             r"(.*)/(.*)/yellow.csv",
             s"yellow/\1/\2.csv")["yellow"]
```

```julia:dir1
yellowdf = exec(reducevalues(vcat, yellow′))

first(yellowdf, 15)
```

Here calling `exec` computes all the values required to compute the result. This means the green taxi data is never loaded into memory in this particular case.

# Parallel invocation

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
