# GZip.jl

[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliaio.github.io/GZip.jl/dev)
[![CI](https://github.com/JuliaIO/GZip.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JuliaIO/GZip.jl/actions/workflows/CI.yml)

A Julia interface for gzip functions in [zlib](http://zlib.net). Provides `GZipStream`, a drop-in `IO` replacement for reading and writing gzip files.

Supports both standard zlib and [zlib-ng](https://github.com/zlib-ng/zlib-ng) backends.

## Quick Start

```julia
using GZip

# Write
GZip.open("data.gz", "w") do io
    write(io, "hello world")
end

# Read
data = GZip.open(read, "data.gz")
```

## zlib-ng Backend

For potentially better performance, use the zlib-ng backend:

```julia
GZip.open("data.gz", "w"; backend=GZip.ZLIBNG) do io
    write(io, "fast compression")
end
```

Files are cross-compatible between backends.

## Documentation

See the [full documentation](https://juliaio.github.io/GZip.jl/dev) for details.
