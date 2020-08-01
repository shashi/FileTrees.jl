# FileTrees

FileTrees lets you walk, filter, load, restructure and save directory structures. Loading, and saving data can occur in parallel.

There are no restrictions on what files you can read and write, as long as you have a function from somewhere in the julia ecosystem (or your own) that can read and write a file.

## API

### Tree manipulation

- FileTree
- filter
- merge
- treediff
- flatten
- prewalk
- postwalk

### Loading, and saving data

- load
- mapvalues
- reducevalues
- save

### Laziness and Parallelism

- lazy
- exec
