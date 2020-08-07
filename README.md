# DirTools

[![Build Status](https://travis-ci.org/shashi/DirTools.jl.svg?branch=master)](https://travis-ci.org/shashi/DirTools.jl) [![AppVeyor status](https://ci.appveyor.com/api/projects/status/ath7hlqi6aofi626/branch/master)](https://ci.appveyor.com/project/shashi/harvest-jl/branch/master) [![Coverage Status](https://coveralls.io/repos/github/shashi/DirTools.jl/badge.svg?branch=master)](https://coveralls.io/github/shashi/DirTools.jl?branch=master)

Reap the fruits of your file trees.

DirTools lets you walk, filter, load, restructure and save directory structures. Loading, processing and saving data can occur in parallel.

There are no restrictions on what files you can read and write, as long as you have functions to work with one file, you can use it to work with a directory of files.

## API

### Tree manipulation

- FileTree
- filter
- merge
- treediff
- flatten
- cp
- mv
- rm
- touch
- mkpath

### Loading, and saving data

- load
- mapvalues
- reducevalues
- save

### Laziness and Parallelism

- lazy
- exec
