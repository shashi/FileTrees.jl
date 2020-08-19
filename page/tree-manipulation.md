# FileTree manipulation

The tree manipulation functions are `map`, `filter`, `mv`, `cp`, `rm`, `merge`, `diff`, `clip`, and `mapsubtrees` in combination with other functions.

A lot of tree manipulation involves pattern matching, so we recommend you read [the section on pattern matching first](/patterns).

## `map` and `filter`

[`map`](/api/#map/filter) can be used to apply a function to every node in a file tree, to create a new file tree. This function should return a `File` or `FileTree` object.

[`filter`](/api/#map/filter) can be used to filter only nodes that satisfy a given predicate function.

Both `map` and `filter` take a `walk` keyword argument which can be either `FileTrees.prewalk` or `FileTrees.postwalk`, they do pre-order traversal and post-order traversal of the tree respectively. By default both operate on both `FileTree` (subtree) nodes and `File` nodes. You can pass in `dirs=false` to work only on the file nodes.

## `merge`

{{doc merge(::FileTree, ::FileTree; combine) merge method}}

## `diff` and `rm`

{{doc diff(::FileTree, ::FileTree) diff method}}

{{doc rm(::FileTree, ::Any) rm method}}

## `mv` and `cp`

The signature of `mv` is `mv(tree::FileTree, r::Regex, s::SubstitutionString; combine)`.

For every file in `tree` whose path matches the regular expression `r`, rewrite its path as decided by `s`. All paths are to be matched with delimiter `/` on all platforms (including Windows).

`mv` and `cp` not only allow you to move or copy nodes within a `FileTree` but also merge many files by copying them to the same path. `combine` is a callback that is called with the values of two files when a file is moved to an already existing or already created path. By default it is set to error on name clashes where either of the nodes has a non-null value.

`s` can be a SubstitutionString, which is conveniently constructed using the [`s""` string macro](https://docs.julialang.org/en/v1/base/strings/#Base.@s_str).

> Within the string, sequences of the form `\N` refer to the Nth capture group in the regex, and `\g<groupname>` refers to a named capture group with name `groupname`.


Example:

```julia:dir1
using FileTrees

tree = FileTree("taxi-data")
```

```julia:dir1
# first move */*/yellow.csv to yellow/*/*.csv

t2 = mv(tree, r"^([^/]*)/([^/]*)/yellow.csv$", s"yellow/\1/\2.csv")

# move */*/green.csv to green/*/*.csv
mv(t2, r"^([^/]*)/([^/]*)/green.csv$", s"green/\1/\2.csv")
```

It's also possible to just move all the yellow files into a single yellow.csv file.

```julia:dir1
mv(tree, r"^([^/]*)/([^/]*)/yellow.csv$", s"yellow.csv")
```

This works when there is no value loaded into the tree, but it probably shouldn't. Let's see what happens when the yellow files have some values loaded in them:


```julia:dir1
using CSV, DataFrames
dfs = FileTrees.load(tree) do file
    DataFrame(CSV.File(path(file)))
end;
```

```julia:dir1
mv(dfs, r".*yellow.csv$", s"yellow.csv")
```

Oh oops! It says pass in `combine=f` where `f` can combine the values of the two clashing files. In our case we want to concatenate the DataFrames, so let's pass in `vcat`.

```julia:dir1
mv(dfs, r".*yellow.csv$", s"yellow.csv", combine=vcat)
```

As you can see, the final yellow.csv file has a value that is a combination of all the yellow.csv values.

We can do the same with the green files:

```julia:dir1
df1 = mv(dfs, r".*yellow.csv$", s"yellow.csv", combine=vcat)
df2 = mv(df1, r".*green.csv$", s"green.csv", combine=vcat)
```


## `mapsubtrees`

[`mapsubtrees(f, pattern)`](/api/#mapsubtrees) lets you apply a function to every node whose path matches `pattern` which is either a Glob or Regex (see also [pattern matching](/patterns)).

`f` gets the subtree itself and may return a subtree which is to replace the one it matched. It can return `nothing` to delete the node in the output tree, returning any other value will cause it to empty the subtree and set the value of the node to the returned value.

This last behavior makes it equivalent to Julia's `mapslices` but on trees.

Suppose you have a nested tree of values, and you would like to join the data in the second level of the tree using `vcat` but the first level of the tree using `hcat`. This can be done in two stages: first use `mapsubtrees` to collapse the second level tree into a single value which is the `vcat` of all the values in each subtree. Then combine those results with an `hcat`.

To demonstrate this let's create a nested tree with a nice structure:

```julia:dir1
tree = maketree("dir"=>
                [string(i)=>[(name=string(j), value=(i,j)) for j in 1:5] for i=1:5])
```

Step 1: reduce level 2 onwards:
```julia:dir1
vcated = mapsubtrees(tree, glob"*") do subtree
    reducevalues(vcat, subtree)
end
```

Step 2: reduce intermediate results

```julia:dir1
reducevalues(hcat, vcated, dirs=true)
```

This can also be done lazily!

```julia:dir1
vcated = mapsubtrees(tree, glob"*") do subtree
    reducevalues(vcat, subtree, lazy=true)
end
```

```julia:dir1
final = reducevalues(hcat, vcated, dirs=true)
```

```julia:dir1
exec(final)
```
