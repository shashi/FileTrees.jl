# Creating and loading images

Here we will use FileTrees to work with some image data.

First let's create some image data. Here we're creating 1000 images of size 1000x1000 each with random pixels. We first create a tree by using `touch` to create the path for each file,

There are other ways of creating trees as well.

```julia
@everywhere using Images, FileTrees, FileIO

t = maketree("imgs" => [])
@time for i = 1:8
    for j = 1:100
        global t = touch(t, "$i/$j.png")
    end
end


@time t1 = FileTrees.load(t; lazy=true) do file
    rand(RGB, 1000, 1000)
end

@time FileTrees.save(t1) do file
    FileIO.save(path(file), file.value)
end |> exec
```

Then let's load it and, say, compute the mean of the `red` channel.

```julia
using Distributed
@everywhere using FileTrees, FileIO, Images, .Threads, Statistics, Distributed

function mean_red()
    t = FileTree("imgs")
    t1 = FileTrees.load(t; lazy=true) do f
        img = FileIO.load(path(f))
        println("pid, ", myid(), "threadid ", threadid(), ": ", path(f))
        sum(red.(img))
    end

    npixels = 10*100*(1000*1000)
    (reducevalues(sum, t1) |> exec) / npixels
end

@time mean_red()
```

Here, to compute the mean we used the sum of the pixel values and then a known total number of pixels, i.e. 10*100*(1000x1000) to average it.

But let's suppose the images you are reading are all of different sizes, this can be done by:

using `reducevalues` to compute both the sum and the total number of pixels.

But there's a cooler way to do this with `OnlineStats`:

```julia
function mean_red()
    t = FileTree("imgs")
    t1 = FileTrees.load(t; lazy=true) do f
        o = Series(Mean(), Variance())
        img = FileIO.load(path(f))
        println("pid, ", myid(), "threadid ", threadid(), ": ", path(f))
        fit!(o, red.(img))
    end

    (reducevalues(merge, t1) |> exec)
end

@time mean_red()
```
It should output something like:
```

 33.764245 seconds (19.48 M allocations: 1.531 GiB, 2.05% gc time)
Series
├─ Mean: n=1000000000 | value=0.500006
└─ Variance: n=1000000000 | value=0.0833369
```
