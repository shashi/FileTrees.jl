# FileTrees.jl changelog

## Version 0.4.0

### Breaking changes

- No longer possible to use `Dagger.Context()` as first input to `exec`. Instead, add `Dagger` as a dependency (since it now is a weak dependency) and use `Executor.Dagger` (note that this uses eager mode).
- `compute` is now only available when `Dagger` is loaded (since it is a `Dagger` function). The returned `FileTree` now has `DTasks` as values instead of `Chunks`.

### Other changes

- Dagger is now a weak depenency.
- Use Daggers eager mode instead of `delayed` (since `delayed` is deprecated).
- FileTrees now vendors it own lazy functionality (should not impact end users unless they interact with Thunks directly in their code).
- Add executors for computing lazy tree in 1) the current task (`Executor.CurrentTask`) and 2) using `Threads.@spawn` (`Executor.Threads` which is the default). 

- ...
