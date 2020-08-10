using Distributed
@everywhere using FileTrees, DataFrames, CSV, Test

@testset "taxi tests" begin
    dir = joinpath(@__DIR__, "..", "page", "taxi-data")
    global taxi_dir = FileTree(dir)
    @test name(taxi_dir) == dir
    @test path(taxi_dir["2019"]) == joinpath(dir, "2019")

    @test path(taxi_dir["2019"]) == joinpath(dir, "2019")
    @test name(FileTrees.rename(taxi_dir, "taxi-data")) == "taxi-data"
end

@testset "loading" begin
    global dfs = FileTrees.load(taxi_dir) do file
        DataFrame(CSV.File(path(file)))
    end

    global lazy_dfs = FileTrees.load(taxi_dir, lazy=true) do file
        DataFrame(CSV.File(path(file)))
    end

    @testset "count files" begin
        @test reducevalues(+, mapvalues(x -> (@test x isa DataFrame; 1), dfs)) == 8
        @test reducevalues(+, mapvalues(x -> (@test x isa DataFrame; 1), dfs, lazy=true)) isa FileTrees.Thunk
        @test exec(reducevalues(+, mapvalues(x -> (@test x isa DataFrame; 1), dfs, lazy=true))) == 8

        @test reducevalues(+, mapvalues(x -> (@test x isa DataFrame; 1), lazy_dfs)) isa FileTrees.Thunk
        @test exec(reducevalues(+, mapvalues(x -> 1, lazy_dfs))) == 8
        # lazy=false
        @test reducevalues(+, mapvalues(x -> x isa FileTrees.Thunk,
                                        lazy_dfs, lazy=false)) == 8
    end

end

@testset "mv" begin
    t2 = mv(dfs, r"^([^/]*)/([^/]*)/yellow.csv$", s"yellow/\1/\2.csv")

    # move */*/green.csv to green/*/*.csv
    t2 = mv(t2, r"^([^/]*)/([^/]*)/green.csv$", s"green/\1/\2.csv")

    # All files must get moved
    @test isempty(setdiff(name.(children(t2)), ["yellow", "green"]))

    # this should throw
    @test_throws ErrorException mv(dfs, r"^([^/]*)/([^/]*)/yellow.csv$", s"yellow.csv")

    yellow = mv(dfs, r"^([^/]*)/([^/]*)/yellow.csv$", s"yellow.csv", combine=vcat)["yellow.csv"]
    @test yellow[] isa DataFrame

    # correct?
    @test Set(DataFrames.Tables.rowtable(reducevalues(vcat, dfs[glob"*/*/yellow.csv"]))) ==
           Set(DataFrames.Tables.rowtable(yellow[]))
end
