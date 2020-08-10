~~~
<h1>FileTrees.jl &mdash; overview</h1>
<p style="font-size: 1.15em; color: #666; line-height:1.5em">
FileTrees is a set of tools to lazy-load, process and write file trees. Built-in parallelism allows you to max out compute on any machine.
</p>
~~~

Tree operations let you freely restructure file trees in memory so as to be convenient to set up computations. Files in a file tree can have any value attached to them (not necessarily those loaded from the file itself), you can map and reduce over these values, or combine them by merging or collapsing trees or subtrees.

**On this website**

~~~
<ul>
<li><a href="create-trees/">Creating file trees</a></li>
<li><a href="values/">Values in file trees: file loading etc.</a></li>
<li><a href="patterns/">Pattern matching on paths</a></li>
<li><a href="tree-manipulation/">Manipulating file trees</a></li>
<li><a href="lazy-parallel/">Lazy values and parallelism</a></li>
<li><a href="api/">API documentation</a></li>
</ul>
~~~

**In this article**

We will look at a brief walk through of some of the most important functionality in this article using an example dataset.

\toc

# Loading directories

The basic datastructure in FileTrees is the [`FileTree`](api/#FileTree).

Calling `FileTree` with a directory name will walk the directory on disk and construct a `FileTree`.

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

Here `load` actually read the files eagerly. This may not be feasible if the files contain data that is too big to fit in memory.

In such a case, you can load the files lazily using `lazy=true`

```julia:dir1
lazy_dfs = FileTrees.load(taxi_dir; lazy=true) do file
    DataFrame(CSV.File(path(file)))
end
```

As you can see the nodes have the value of type `Dagger.Thunk` -- this represents a lazy task that can later be executed using the [`exec`](api/#exec) function. You can continue to use most of the functions in this package without worrying about whether the input tree has lazy values or not. You will get the corresponding lazy outputs wherever the input trees had lazy values. Lazy values also encode dependency between them, hence making it possible for `exec` to compute them in parallel.

To know more details about the usage of laziness and parallelism, go to [this article](lazy-parallel/).

# Looking files up

Let's look at one of these DataFrames by indexing into the tree with the path to a file, namely `"2020/01/yellow.csv"`.

```julia:dir1
yellow_jan_20 = dfs["2020/01/yellow.csv"]
```

`file[]` syntax fetches the value stored in a `File` or `FileTree` node:

```julia:dir1
yellow_jan_20[] # file[] gets the value
```

When a tree is lazy, the `[]` operation returns a `Thunk`, a delayed computation.

You can call `exec` on the this value to compute and fetch the value.


```julia:dir1
val = lazy_dfs["2020/01/yellow.csv"][]
@show typeof(val)
@show exec(val);
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


See the [pattern matching](patterns/) documentation to learn more about how to use pattern matching to manipulate trees.

# reducing values in trees

Now that we have files with the same schema in different trees,  we can reduce either tree with `vcat` function on DataFrames to combine the dataframes into a single dataframe:

```julia:dir1
yellowdf = reducevalues(vcat, yellow)

first(yellowdf, 15)
```

`reducevalues` also works on the lazy tree but returns a lazy final result. You can call `exec` on it to actually compute it. This causes the computation to occur in parallel!

```julia:dir1
yellowdf = exec(reducevalues(vcat, lazy_dfs[r"yellow.csv$"]))

first(yellowdf, 15)
```

Note that in the lazy case the green csv files are never loaded since they are not required to compute the final result!


# Saving to a directory

```julia:dir1
df1 = dfs[r"yellow.csv$"]

# this mv moves X/Y/yellow.csv to yellow/X/Y.csv
# see the Tree manipulation section of the docs for more

df2 = mv(df1, r"^([^/]*)/([^/]*)/yellow.csv$",
              s"yellow/\1/\2.csv")["yellow"]

@show df2

FileTrees.save(setparent(df2, nothing)) do file
    CSV.write(path(file), file[])
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
