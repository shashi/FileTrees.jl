using Distributed
@everywhere using Test
@everywhere using FileTrees
@everywhere using FileTrees: Thunk, NoValue
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

# Helper function to recursively check that all children of ft have ft as their parent
function isconsistent(ft)
    ok = true
    for c in children(ft)
        ok = parent(c) === ft && isconsistent(c)
    end
    return ok
end

@testset "indexing" begin
    @test name(t) == "."
    @test t["a"]["b"]["a"] isa File
    @test t["a"]["c"]["c"] isa FileTree

    @test Path(t["a"]["b"]["a"])  == p"." /"a"/"b"/"a"

    t1 = FileTrees.rename(t, "foo")
    @test Path(t1["a"]["b"]["a"])  == p"foo" /"a"/"b"/"a"

    @test isequal(t[r"a|b"], t)

    @test isempty(t[r"^c"])

    @test isequal(t["a"]["c"][["b", r"a|d"]],
                  maketree("c" => ["b","a"]))

    @test_throws ErrorException t["c"]

    @test isconsistent(t[r"a|c"])
    @test isconsistent(t[glob"a/*/*"])
end

@testset "filter" begin
    @test isequal(filter(f->f isa FileTree || name(f) == "c", t),
                  maketree(["a"=>["b"=>[],
                                  "c"=>["c"=>[]]]]))
end

@testset "merge" begin
    @test isequal(merge(t,t), t)

    # Check that we don't rearrange the tree more than necessary
    t2 =  maketree(["b" => ["x"], "a" => ["y"]])
    t3 =  maketree(["c" => ["x"], "a" => ["z"]])
    @test name.(children(merge(t2, t3))) == ["b", "a", "c"]
    @test name.(children(merge(t3, t2))) == ["c", "a", "b"]
    @test isequal(merge(t2, t3), merge(t3,t2))
end

@testset "diff" begin
    @test isempty(FileTrees.diff(t,t))
    @test isequal(FileTrees.diff(t,maketree([])), t)
end

import FileTrees: attach

@testset "touch mv and cp" begin
    global t1 = maketree([])
    for yr = 1:9
        global t1 = mkpath(t1, joinpath(string("0", yr)), value=yr)
        for mo = 1:6
            global t1 = attach(t1, joinpath(string("0", yr), string("0", mo)),
                        File(nothing, "data.csv", (yr, mo)) )
        end
    end

    @test isconsistent(t1)

    data1 = reducevalues(vcat, t1) |> exec

    t4 = mv(t1, r"^(.*)/(.*)/data.csv$", s"\1/\2.csv")

    @test isconsistent(t4)

    t5 = maketree([])
    for yr = 1:9
        for mo = 1:6
            t5 = attach(t5, joinpath(string("0", yr)),
                        File(nothing, string("0", mo) * ".csv", (yr, mo)))
        end
    end

    @test isconsistent(t5)

    @test isequal(t4, t5)

    data2 = reducevalues(vcat, t4) |> exec

    @test data1 == data2

    t7 = mapsubtrees(t1, glob"*") do subtree
        reducevalues(vcat, subtree)
    end

    @test isconsistent(t7)

    @test reducevalues(hcat, t7; dirs=true) == [(j, i) for i=1:6, j=1:9]

    t6 = cp(t1, r"^(.*)/(.*)/data.csv$", s"\1/\2.csv")

    @test isconsistent(t6)

    @test isequal(t6, merge(t1, t5))

    @testset "$fun combine$(associative ? " associative" : "")" for fun in (cp, mv), associative in (false, true)
        tcombine = maketree([
                            "a" => [(name="y", value="ay"), (name ="x", value="ax")], 
                            "b" => [(name ="x", value="bx"), (name="y", value="by")],
                            "c" => [(name ="x", value="cx"), (name="y", value="cy")],
                            ])
        tcombined = mv(tcombine, r"^([^/]*)/([xy])", s"\2"; combine=(v1,v2) -> v1 * "_" * v2, associative=associative)

        @test tcombined["x"][] == "ax_bx_cx"
        @test tcombined["y"][] == "ay_by_cy"
        # Also test that we maintained the same order as the first encountered node
        @test name.(children(tcombined)) == ["y", "x"]
    end
end

@testset "values" begin
    mktempdir() do rootpath
        testdir = joinpath(rootpath, "test_dir")
        t1 = FileTrees.load(path, t)

        @test get(t1["a/b/a"]) == string(p"." / "a" / "b" / "a")

        @test reducevalues(*, mapvalues(lowercase, t1)) == lowercase(reducevalues(*, t1))

        FileTrees.save(maketree(testdir => [t1])) do f
            @test f isa File
            @test parent(f) isa FileTree
            open(path(f), "w") do io
                print(io, get(f))
            end
        end

        t2 = FileTree(testdir)
        t3 = FileTrees.load(t2) do f
            open(path(f), "r") do io
                String(read(io))
            end
        end

        t4 = filter(!isempty, t1)

        @test isequal(t3, FileTrees.rename(t4, testdir))

        x1 = maketree("a"=>[(name="b", value=1)])
        x2 = mapvalues(x->NoValue(), x1, lazy=true)
        @test !isempty(values(x2))
        @test isempty(values(exec(x2)))
        x3 = mapvalues(x->rand(), x2)
        @test !isempty(values(x3))
        @test isempty(values(exec(x3)))

        # issue 16
        @test_throws ArgumentError reducevalues(+, maketree("." => []))
        @test reducevalues(+, maketree("." => []), init=0) === 0

        @test_throws Union{ArgumentError,MethodError} reducevalues(+, maketree("." => []), associative=false)
        @test reducevalues(+, maketree("." => []), init=0, associative=false) === 0

        # issue 23
        @test FileTrees.save(identity, maketree([])) === nothing
    end
end

@testset "lazy-exec" begin

    mktempdir() do rootpath
        testdir = joinpath(rootpath, "test_dir_lazy")

        t1 = FileTrees.load(uppercase∘path, t, lazy=true)

        @test get(t1["a/b/a"]) isa Thunk
        @test get(exec(t1)["a/b/a"]) == string(p"."/"A"/"B"/"A")
        # Exec a single File
        @test get(exec(t1["a/b/a"])) == string(p"."/"A"/"B"/"A")

        @test exec(reducevalues(*, mapvalues(lowercase, t1))) == lowercase(exec(reducevalues(*, t1)))

        s = FileTrees.save(maketree(testdir => [t1])) do f
            @test f isa File
            @test parent(f) isa FileTree
            open(path(f), "w") do io
                print(io, get(f))
            end
        end

        @test isfile(joinpath(testdir, "a/b/a"))

        t2 = FileTree(testdir)
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
        @test isequal(t5, FileTrees.rename(t4, testdir))
    end
end

# TODO: Just remove if we anyways can't select which context to use in Daggers eager/standard API?
#= @testset "exec with context" begin
    import Dagger

    struct SpecialContext end

    computespecial = Ref(false)
    function Dagger.compute(::SpecialContext, t::Dagger.Thunk, kws...)
        computespecial[] = true
        compute(Dagger.Context(procs()), t; kws...)
    end
    ncollectspecial = Ref(0)
    function Dagger.collect(::SpecialContext, c::Dagger.Chunk; kws...)
        ncollectspecial[] += 1
        collect(Dagger.Context(procs()), c; kws...)
    end

    t = mapvalues(identity, maketree("a" => ["b" => [(name="c", value=1)], "d" => ["e" => [(name="f", value=2), (name="g", value=3)]]]), lazy=true)

    @test exec(SpecialContext(), t) |> values == [1,2,3]
    @test computespecial[] == true # Dummy compare to make failed test outprint a little less confusing
    @test ncollectspecial[] == 3 # All values are collected with SpecialContext
end =#


@testset "iterators" begin
    @test values(t1) == map(get, filter(hasvalue, nodes(t1)))
    @test values(t1, dirs=false) != values(t1, dirs=true)
    @test values(t1, dirs=false) == reducevalues(vcat, t1)
    @test values(t1, dirs=true) == map(get, filter(hasvalue, nodes(t1)))
    @test nodes(t1) == collect(FileTrees.PostOrderDFS(t1))
    @test nodes(t1, dirs=false) == collect(Iterators.filter(x->x isa File, FileTrees.PostOrderDFS(t1)))
    @test files(t1) == collect(nodes(t1, dirs=false))
    @test dirs(t1) == collect(Iterators.filter(x->x isa FileTree, nodes(t1, dirs=true)))
end
