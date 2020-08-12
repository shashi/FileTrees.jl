# Working with metadata

\blurb{Metadata of trees are other trees with the same structure}

FileTrees only allow you to store one value per node, but sometimes you also want to have metadata that is small and has information about the contents of the files.

In FileTrees, you can create a new tree which contains the metadata! This tree can mirror the structure of the tree with the actual data. You can operate on the metadata tree, for example, to filter out nodes based on the metadata, and then _index into the tree with the actual data with the metadata tree_ to apply the same filtering.

In the taxi dataset we may want to have metadata about what are the RatecodeId present in each file:

```julia:dir1
using FileTrees, DataFrames, CSV

taxi_dir = FileTree("taxi-data")

# Lazy-load the data
data = FileTrees.load(taxi_dir;lazy=true) do file
    DataFrame(CSV.File(path(file)))
end


# Get the metadata
metadata = mapvalues(data) do df
    (unique(df.RatecodeID)...,)
end |> exec
```

Once this metadata is created, you can store the tree in a JLD2 file, and read it back often. Or you can also store it in a new file in the same directory.

Now let's say you want to load only the data for files which contain the RetecodeID 5.

First we work on the metadata tree to filter it thus:

```julia:dir1
only_5 = filter(x->FileTrees.hasvalue(x) && (5 in x[]), metadata, dirs=false)
```

You can now "index" into the data to get only files with this structure.

```julia:dir1
data[only_5]
```

# Conclusion

So the way to deal with metadata is: to create a tree with the metadata, filter that tree based on the metadata, then index into the data tree with the filtered tree!
