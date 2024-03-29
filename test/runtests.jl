using Test
using Distributed, .Threads

if nprocs() == 1 && nthreads() == 1
    # Lazy stuff should also test distributed
    println("Adding a proc")
    addprocs(1; exeflags="--project")
end

@testset "basics" begin include("basics.jl"); end
@testset "taxi" begin include("taxi.jl"); end

if nprocs() > 1
    rmprocs(workers())
end