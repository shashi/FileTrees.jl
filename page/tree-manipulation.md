# FileTree manipulation

The tree manipulation functions are `mv`, `cp`, `rm`, `clip`, `flatten`, and `mapsubtrees` in combination with other functions.

A lot of tree manipulation involves pattern matching, so we recommend you read [the section on pattern matching first](/patterns).

## `mv` and `cp`

`mv` and `cp` not only allow you to move or copy nodes within a `FileTree` but also merge many files by copying them to the same path.

The signature of `mv` is `mv(tree::FileTree, r::Regex, s::SubstitutionString; combine)`.

For every file in `tree` whose path matches the regular expression `r`, rewrite its path as decided by `s`. All paths are to be matched with delimiter `/` on all platforms (including Windows).

`combine` is a callback that is called with the values of two files when a file is moved to an already existing or already created path. By default it is set to error on name clashes where either of the nodes has a non-null value.

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

This just works when there is no value loaded into the tree. But let's see what happens when the yellow files have some values loaded in them:


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
