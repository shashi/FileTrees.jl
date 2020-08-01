using Test

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
                                .
                                └─ a
                                   ├─ b
                                   │  └─ a
                                   └─ c
                                      ├─ b
                                      ├─ a
                                      └─ c"""
end

@testset "filter" begin
    @test isequal(filter(f->f isa FileTree || name(f) == "c", t),
                  maketree(["a"=>["b"=>[],
                                  "c"=>["c"=>[]]]]))
end

@testset "flatten" begin
end

@testset "merge" begin
end

@testset "treediff" begin
end

@testset "load" begin
end

@testset "mapvalues" begin
end

@testset "reducevalues" begin
end

@testset "save" begin
end

@testset "lazy-exec" begin
end
