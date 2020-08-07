# DirTools

[![Build Status](https://travis-ci.org/shashi/DirTools.jl.svg?branch=master)](https://travis-ci.org/shashi/DirTools.jl) [![AppVeyor status](https://ci.appveyor.com/api/projects/status/ath7hlqi6aofi626/branch/master)](https://ci.appveyor.com/project/shashi/harvest-jl/branch/master) [![Coverage Status](https://coveralls.io/repos/github/shashi/DirTools.jl/badge.svg?branch=master)](https://coveralls.io/github/shashi/DirTools.jl?branch=master)


**Note:** this package is a work in progress, the API is undocumented and still in flux. Talk to me or Julian about using or contributing.

DirTools is a set of tools to lazy-load, process and write file trees. Built-in parallelism allows you to max out compute on any machine.

There are no restrictions on what files you can read and write, as long as you have functions to work with one file, you can use the same to work with a directory of files.

Lazy directory operations let you freely restructure file trees so as to be convenient to set up computations. Tree manipulation functions help with this. Files in a Dir tree can have any value attached to them, values can be combined by merging trees or subtrees, and written to disk.

## API

### Tree manipulation

- Dir
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
