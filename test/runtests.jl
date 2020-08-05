using Test
using FileTrees

t = maketree(["a" => ["b" => ["a"],
                      "c" => ["b", "a", "c"=>[]]]])

@testset "indexing" begin
    @test name(t) == "."
    @test t["a"]["b"]["a"] isa File
    @test t["a"]["c"]["c"] isa FileTree

    @test path(t["a"]["b"]["a"])  == "./a/b/a"

    t1 = FileTrees.rename(t, "foo")
    @test path(t1["a"]["b"]["a"])  == "foo/a/b/a"

    @test isequal(t[r"a|b"], t)

    @test isempty(t[r"c"])

    @test isequal(t["a"]["c"][["b", r"a|d"]],
                  maketree("c" => ["b","a"]))

    @test_throws ErrorException t["c"]
end

@testset "repr" begin
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

@testset "filter" begin
    @test isequal(filter(f->f isa FileTree || name(f) == "c", t),
                  maketree(["a"=>["b"=>[],
                                  "c"=>["c"=>[]]]]))
end

@testset "flatten" begin
    @test isequal(FileTrees.flatten(t, joinpath=(x,y)->"$(x)/$y"),
                  maketree(["a/b/a", "a/c/b", "a/c/a", "a/c/c"=>[]]))

    @test isequal(FileTrees.flatten(t),
                  maketree(["a_b_a", "a_c_b", "a_c_a", "a_c_c"=>[]]))
end

@testset "merge" begin
    @test_throws Any merge(t,t)
    @test isequal(merge(t,t; combine=(x,y)->y), t)
end

@testset "treediff" begin
    @test isempty(FileTrees.treediff(t,t))
    @test isequal(FileTrees.treediff(t,maketree([])), t)
end

@testset "values" begin
    t1 = load(x->uppercase(path(x)), t)

    @test FileTrees.value(t1["a/b/a"]) == "./A/B/A"

    @test reducevalues(*, mapvalues(lowercase, t1)) == lowercase(reducevalues(*, t1))

    save(maketree("test_dir" => [t1])) do f
        @test f isa File
        open(path(f), "w") do io
            print(io, FileTrees.value(f))
        end
    end

    t2 = FileTree("test_dir")
    global  t3 = load(t2) do f
        open(path(f), "r") do io
            String(read(io))
        end
    end

    t4 = filter(!isempty, t1)

    @test isequal(t3, FileTrees.rename(t4, "test_dir"))
end

using FileTrees: Lazy
using Dates

@testset "lazy-exec" begin

    if isdir("test_dir_lazy")
        rm("test_dir_lazy", recursive=true)
    end


    global t1 = load(x->uppercase(path(x)), t, lazy=true)

    @test FileTrees.value(t1["a/b/a"]) isa Lazy
    @test FileTrees.value(exec(t1)["a/b/a"]) == "./A/B/A"

    @test exec(reducevalues(*, mapvalues(lowercase, t1))) == lowercase(exec(reducevalues(*, t1)))

    s = save(maketree("test_dir_lazy" => [t1])) do f
        open(path(f), "w") do io
            print(io, FileTrees.value(f))
        end
    end

    # dirs got created
    @test !isdir("test_dir_lazy")
    # files not yet created
    @test !isfile("test_dir_lazy/a/b/a")

    exec(s)

    @test isdir("test_dir_lazy")
    @test isfile("test_dir_lazy/a/b/a")


    t2 = FileTree("test_dir_lazy")
    global  t3 = load(t2; lazy=true) do f
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
end
