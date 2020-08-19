# FileTrees as a parallel shell

Think of FileTrees as a Unix shell with `mv`, `cp`, `rm`, `find`, and a bit of `awk`, but you can also use Julia code in between! Trees can be lazy and materialized in parallel using threads and distributed processes. Tree operations are pure functions, so you can reuse tree states as you wish.

Lazy file loading delays loading them until an operation such as `save` and `exec` require the data in the tree. The chain of operations is performed to materialize the result, if valid, in parallel!

You can also make intermediate lazy results be cached in distributed memory.

Any operation that may overwrite an existing or write to the same destination multiple file will fail by default but can be provided with a `combine=f` callback which will be called to combine the values in those files. (maybe you want to append the data instead of overwriting!). This overwrite callback is also applied lazily if any of the inputs are lazy. And eventually computed using the parallelism.


Here is a simple example of using `mv` to take a tree of dataset like this:


```julia:dir1
using FileTrees

taxi_dir = FileTree("taxi-data")
```

And turn it into:

```julia
collated/
├─ green.csv
└─ yellow.csv
```

Where the final `green.csv` contains the result of some computation on all `green.csv` files. And correspondingly `yellow.csv` of all `yellow.csv`s.


First load the files in the tree as DataFrames:

```julia:dir1
using CSV, DataFrames

t = FileTrees.load(taxi_dir) do file
    DataFrame(CSV.File(path(file)))
end
```
Do a groupby on each DataFrame:

```julia:dir1
using Statistics

t = mapvalues(t) do df
    combine(groupby(df, :payment_type), :total_amount => mean)
end
```

Move every `green.csv` file to a file called `green.csv` at the root of the tree. Use `vcat` on the DataFrames to merge files that are moved to the same destination:

```julia:dir1
t = mv(t, r".*/.*/green.csv", s"green.csv"; combine=vcat)
```

Do the same with `yellow.csv`s:

```julia:dir1
t = mv(t, r".*/.*/yellow.csv", s"yellow.csv"; combine=vcat)
```

Look at the result:

```julia:dir1
get(t["green.csv"])
```

```julia:dir1
get(t["yellow.csv"])
```

Save this new directory:

```julia:dir1
FileTrees.save(FileTrees.rename(t, "collated")) do file
    CSV.write(path(file), get(file))
end
```

Verify:

```julia:dir1
FileTree("collated")
```

## now for lazy=true

Simply passing `lazy=true` to `FileTrees.load` and leaving the rest of the code the same will cause the whole computation to occur in parallel:

```julia:dir1
using Distributed

@everywhere FileTrees # @everywhere loads the package on all processors
@everywhere using CSV, DataFrames

t = FileTrees.load(taxi_dir; lazy=true) do file
    DataFrame(CSV.File(path(file)))
end
```

```julia:dir1
using Statistics

t = mapvalues(t) do df
    combine(groupby(df, :payment_type), :total_amount => mean)
end
```

Notice that this time the nodes are `Thunk`s! these are lazy values, not yet computed.
```julia:dir1
t = mv(t, r".*/.*/green.csv", s"green.csv"; combine=vcat)
t = mv(t, r".*/.*/yellow.csv", s"yellow.csv"; combine=vcat)
```

```julia:dir1
FileTrees.save(FileTrees.rename(t, "lazily_collated")) do file
    CSV.write(path(file), get(file))
end
```

Verify:

```julia:dir1
result = FileTrees.load(DataFrame∘CSV.File∘path, FileTree("lazily_collated"))
```

```julia:dir1
@show result["yellow.csv"][]
@show result["green.csv"][]
```
