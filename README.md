# <a href="http://shashi.biz/FileTrees.jl">FileTrees</a>

[![Build Status](https://travis-ci.org/shashi/FileTrees.jl.svg?branch=master)](https://travis-ci.org/shashi/FileTrees.jl) [![Build status](https://ci.appveyor.com/api/projects/status/6sei8e7et721usx6?svg=true)](https://ci.appveyor.com/project/shashi/filetrees-jl)
 [![Coverage Status](https://coveralls.io/repos/github/shashi/FileTrees.jl/badge.svg?branch=master)](https://coveralls.io/github/shashi/FileTrees.jl?branch=master)
 
Easy everyday parallelism with a file tree abstraction.

## Installation

```julia
using Pkg
Pkg.add("FileTrees")
```

## With FileTrees you can

- Read a directory structure as a Julia data structure, (lazy-)load the files, apply map and reduce operations on the data while not exceeding available memory if possible. ([docs](http://shashi.biz/FileTrees.jl/values/))
- Filter data by file name using familiar Unix syntax ([docs](http://shashi.biz/FileTrees.jl/patterns/))
- Make up a file tree in memory, create some data to go with each file (in parallel), write the tree to disk (in parallel). (See example below)
- Virtually `mv` and `cp` files within trees, merge and diff trees, apply different functions to different subtrees. ([docs](http://shashi.biz/FileTrees.jl/tree-manipulation/))

[Go to the documentation &rarr;](http://shashi.biz/FileTrees.jl)

## Example

Here is an example of using FileTrees to create a 3025 images which form a big 16500x16500 image of a Mandelbrot set (I tried my best to make them all contiguous, it's almost right, but I'm still figuring out those parameters.)

Then we load it back and compute a Histogram of the HSV values across all the images in parallel using OnlineStats.jl.

```julia
@everywhere using Images, FileTrees, FileIO

tree = maketree("mandel"=>[]) # an empty file tree
params = [(x, y) for x=-1:0.037:1, y=-1:0.037:1]
for i = 1:size(params,1)
    for j = 1:size(params,2)
        tree = touch(tree, "$i/$j.png"; value=params[i, j])
    end
end

# map over the values to create an image at each node.
# 300x300 tile per image.
t1 = FileTrees.mapvalues(tree, lazy=true) do params
    mandelbrot(50, params..., 300) # zoom level, moveX, moveY, size
end
 
# save it
@time FileTrees.save(t1) do file
    FileIO.save(path(file), file.value)
end
```
This takes about 150 seconds when Julia is started with 10 processes with 4 threads each, in other words on a 12 core machine. (oversubscribing this much gives good perormance in this case.)
 In other words,
```
export JULIA_NUM_THREADS=4
julia -p 10
```

Then load it back in a new session:

```julia
using Distributed
@everywhere using FileTrees, FileIO, Images, .Threads, OnlineStats, Distributed

t = FileTree("mandel")

# Lazy-load each image and compute its histogram
t1 = FileTrees.load(t; lazy=true) do f
    h = Hist(0:0.05:1)
    img = FileIO.load(path(f))
    println("pid, ", myid(), "threadid ", threadid(), ": ", path(f))
    fit!(h, map(x->x.v, HSV.(img)))
end

# combine them all into one histogram using `merge` method on OnlineStats

@time h = reducevalues(merge, t1) |> exec # exec computes a lazy value
```
Plot the Histogram:

```julia
        ┌                                        ┐ 
    0.0 ┤■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ 100034205   
   0.05 ┤ 302199                                   
    0.1 ┤ 666776                                   
   0.15 ┤ 378473                                   
    0.2 ┤ 864297                                   
   0.25 ┤ 1053490                                  
    0.3 ┤ 602937                                   
   0.35 ┤ 667619                                   
    0.4 ┤ 1573476                                  
   0.45 ┤ 949928                                   
    0.5 ┤■ 2370727                                 
   0.55 ┤ 1518383                                  
    0.6 ┤■ 3946507                                 
   0.65 ┤■■ 6114414                                
    0.7 ┤■ 4404784                                 
   0.75 ┤■■ 5920436                                
    0.8 ┤■■■■■■ 20165086                           
   0.85 ┤■■■■■■ 19384068                           
    0.9 ┤■■■■■■■■■■■■■■■■■■■■■■ 77515666           
   0.95 ┤■■■■■■■ 23816529                          
        └                                        ┘ 

```
this takes about 100 seconds.

At any point in time the whole computation holds 40 files in memory, because there are 40 computing elements 4 threads x 10 processes. The scheduler also takes care of freeing any memory that it knows will not be used after the result is computed. This means you can work on data that on the whole will not fit in memory.

<a href="https://shashi.github.io/FileTrees.jl">See the docs &rarr;</a>
