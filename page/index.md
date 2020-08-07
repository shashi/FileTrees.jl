# What is DirTools?

~~~
<p style="font-size: 1.15em; color: #666; line-height:1.5em">
DirTools is a set of tools to lazy-load, process and write file trees. Built-in parallelism allows you to max out compute on any machine.
</p>
~~~

There are no restrictions on what files you can read and write. If you have functions to work with one file, you can use the same to work with a file tree.

Lazy tree operations let you freely restructure file trees so as to be convenient to set up computations. Files in a file tree can have any value attached to them (not necessarily those loaded from the file itself), values in these nodes can be combined by merging trees or subtrees.


## Introduction

The basic datastructure in DirTools is the `Dir` tree. The nodes of this tree can be themselves `Dir` or `File` objects. Each node contains a `name` field which shows its name.

```julia:dir1
using DirTools

Dir("test_data")
```
\out{dir1}

A Dir tree, does not necessarily have to do with a directory on disk, it can be created on the fly, and may or may not be saved to disk.
