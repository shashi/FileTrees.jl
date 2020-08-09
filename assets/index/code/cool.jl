# This file was generated, do not modify it. # hide
using Distributed, .Threads
@everywhere using DirTools, CSV, DataFrames

lazy_dfs = DirTools.load(taxi_dir; lazy=true) do file
    # println("Loading $(path(file)) on $(myid()) on thread $(threadid())")
    DataFrame(CSV.File(path(file)))
end

first(exec(reducevalues(vcat, lazy_dfs[r"yellow.csv$"])), 15)