# Creating file trees

As seen on the home page, the easiest way to create a FileTree is to call `FileTree` with the path to a directory on disk.

```julia:dir1
using FileTrees

taxi_dir = FileTree("taxi-data")
```

But a `FileTree` does not have to reflect files on a disk. You can "virtually" create a tree using the [`maketree`](api/#maketree) function:


```julia:dir1
maketree("mydir" => ["foo" => ["baz"], "bar"])
```

You can also construct a tree with nodes that have values!

```julia:dir1
t1 = maketree("mydir" => ["foo" => [(name="baz", value=42)], "bar"])
```

```julia:dir1
get(t1["foo"]["baz"])
```

Another neat way of constructing a tree is to use `touch` to create files in an empty `FileTree`.

```julia:dir1
t = maketree("mydir"=>[])

for i=1:3
    for j=1:2
        global t = touch(t, "$i/$j/data.csv"; value=rand(10))
    end
end
t
```

This last method is slower and is not recommended if you are creating thousands of files.
