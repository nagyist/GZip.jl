# GZip.jl

[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliaio.github.io/GZip.jl/dev)
[![CI](https://github.com/JuliaIO/GZip.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JuliaIO/GZip.jl/actions/workflows/CI.yml)

A Julia interface for gzip functions in [zlib](http://zlib.net). Provides `GZipStream` for reading and writing gzip files, with zlib-ng support and gzip header metadata access.

Defaults to the [zlib-ng](https://github.com/zlib-ng/zlib-ng) backend for up to 2.5x faster compression and 2.2x faster decompression. Standard zlib is also available via `backend=GZip.ZLIB`.

## Quick Start

```julia
using GZip

# Write
GZip.open("data.gz", "w") do io
    write(io, "hello world")
end

# Read
data = GZip.open(read, "data.gz")

# Header metadata
h = gzheader("data.gz")
h.name     # original filename
h.mtime    # modification time
```

Use the standard zlib backend if needed:

```julia
GZip.open("data.gz", "w"; backend=GZip.ZLIB) do io
    write(io, "compressed with zlib")
end
```

Files are cross-compatible between backends.

## GZip.jl vs CodecZlib.jl

**For most users, we recommend [CodecZlib.jl](https://github.com/JuliaIO/CodecZlib.jl).** It provides a more complete and well-tested `IO` interface via [TranscodingStreams.jl](https://github.com/JuliaIO/TranscodingStreams.jl), supports in-memory compression, and handles gzip, zlib, and raw deflate formats.

GZip.jl is a thin wrapper around zlib's `gz*` C functions, which handle file I/O and paths directly in C rather than through Julia's `IOStream`. This means GZip.jl does not benefit from the ongoing work in Base Julia to make file I/O and path handling behave consistently across all supported platforms. It is useful if you specifically need zlib-ng performance or gzip header metadata access, but its `IO` implementation is less complete and less widely tested (8 direct dependents vs CodecZlib.jl's 149).

| | GZip.jl | CodecZlib.jl |
|:---|:---|:---|
| **Recommended for most users** | | **Yes** |
| **IO interface completeness** | Partial | Full (via TranscodingStreams) |
| **Best for** | File-based gzip I/O | General-purpose streaming compression |
| **zlib-ng support** | Yes (default backend) | No |
| **In-memory compress/decompress** | No | Yes |
| **Raw deflate/zlib format** | No (gzip only) | Yes |
| **Header metadata** | Yes (`gzheader`) | No |

**Use GZip.jl** when you need zlib-ng performance or gzip header metadata access.

**Use [Inflate.jl](https://github.com/GunnarFarneback/Inflate.jl)** if you want a pure Julia library for header metadata access and decompression.

**Use [ChunkCodecLibZlib.jl](https://github.com/JuliaIO/ChunkCodecs.jl/tree/main/LibZlib)** when you need one-shot in-memory compression with configurable compression level and output size hints.

## Documentation

See the [full documentation](https://juliaio.github.io/GZip.jl/dev) for details, including [benchmarks](test/README.md).
