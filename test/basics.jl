using Distributed
@everywhere using Test
@everywhere using FileTrees
@everywhere using FileTrees: Thunk
@everywhere using Dates
@everywhere import FilePathsBase: /

@testset "maketree" begin
    global t = maketree(["a" => ["b" => ["a"],
                                 "c" => ["b", "a", "c"=>[]]]])

    @test strip(repr(t)) == """
                            ./
                            └─ a/
                               ├─ b/
                               │  └─ a
                               └─ c/
                                  ├─ b
                                  ├─ a
                                  └─ c/"""
end

@testset "indexing" begin
    @test name(t) == "."
    @test t["a"]["b"]["a"] isa File
    @test t["a"]["c"]["c"] isa FileTree

    @test path(t["a"]["b"]["a"])  == p"." /"a"/"b"/"a"

    t1 = FileTrees.rename(t, "foo")
    @test path(t1["a"]["b"]["a"])  == p"foo" /"a"/"b"/"a"

    @test isequal(t[r"a|b"], t)

    @test isempty(t[r"^c"])

    @test isequal(t["a"]["c"][["b", r"a|d"]],
                  maketree("c" => ["b","a"]))

    @test_throws ErrorException t["c"]
end

@testset "filter" begin
    @test isequal(filter(f->f isa FileTree || name(f) == "c", t),
                  maketree(["a"=>["b"=>[],
                                  "c"=>["c"=>[]]]]))
end

@testset "cp" begin
    @test isequal(cp(t,t), t)
end

@testset "rm" begin
    @test isempty(FileTrees.rm(t,t))
    @test isequal(FileTrees.rm(t,maketree([])), t)
end

import FileTrees: attach

@testset "touch mv and cp" begin
    global t1 = maketree([])
    for yr = 1:9
        for mo = 1:6
            t1 = attach(t1, joinpath(string("0", yr), string("0", mo)),
                        File(nothing, "data.csv", (yr, mo)) )
        end
    end
    data1 = reducevalues(vcat, t1) |> exec

    t4 = mv(t1, r"^(.*)/(.*)/data.csv$", s"\1/\2.csv")

    t5 = maketree([])
    for yr = 1:9
        for mo = 1:6
            t5 = attach(t5, string("0", yr),
                        File(nothing, string("0", mo) * ".csv", (yr, mo)))
        end
    end

    @test isequal(t4, t5)

    data2 = reducevalues(vcat, t4) |> exec

    @test data1 == data2

    t6 = cp(t1, r"^(.*)/(.*)/data.csv$", s"\1/\2.csv")

    @test isequal(t6, cp(t1, t5))
end

@testset "values" begin
    t1 = FileTrees.load(x->string(path(x)), t)
    if isdir("test_dir")
        rm("test_dir", recursive=true)
    end

    @test t1["a/b/a"][] == string(p"." / "a" / "b" / "a")

    @test reducevalues(*, mapvalues(lowercase, t1)) == lowercase(reducevalues(*, t1))

    FileTrees.save(maketree("test_dir" => [t1])) do f
        @test f isa File
        open(path(f), "w") do io
            print(io, f[])
        end
    end

    t2 = FileTree("test_dir")
    t3 = FileTrees.load(t2) do f
        open(path(f), "r") do io
            String(read(io))
        end
    end

    t4 = filter(!isempty, t1)

    @test isequal(t3, FileTrees.rename(t4, "test_dir"))
    if isdir("test_dir")
        rm("test_dir", recursive=true)
    end
end

@testset "lazy-exec" begin

    if isdir("test_dir_lazy")
        rm("test_dir_lazy", recursive=true)
    end


    t1 = FileTrees.load(x->uppercase(string(path(x))), t, lazy=true)

    @test t1["a/b/a"][] isa Thunk
    @test exec(t1)["a/b/a"][] == string(p"."/"A"/"B"/"A")

    @test exec(reducevalues(*, mapvalues(lowercase, t1))) == lowercase(exec(reducevalues(*, t1)))

    s = FileTrees.save(maketree("test_dir_lazy" => [t1])) do f
        open(path(f), "w") do io
            print(io, f[])
        end
    end

    @test isdir("test_dir_lazy")
    @test isfile("test_dir_lazy/a/b/a")


    t2 = FileTree("test_dir_lazy")
    t3 = FileTrees.load(t2; lazy=true) do f
        open(path(f), "r") do io
            (String(read(io)), now())
        end
    end
    toc = now()
    sleep(0.01)
    tic = exec(reducevalues((x,y)->x, mapvalues(last, t3)))

    @test tic > toc

    t4 = filter(!isempty, t1) |> exec

    t5 = mapvalues(first, t3) |> exec
    @test isequal(t5, FileTrees.rename(t4, "test_dir_lazy"))

    if isdir("test_dir_lazy")
        rm("test_dir_lazy", recursive=true)
    end
end

