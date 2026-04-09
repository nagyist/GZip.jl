# GZip.jl

[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliaio.github.io/GZip.jl/dev)
[![CI](https://github.com/JuliaIO/GZip.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JuliaIO/GZip.jl/actions/workflows/CI.yml)

A Julia interface for gzip functions in [zlib](http://zlib.net). Provides `GZipStream`, a drop-in `IO` replacement for reading and writing gzip files.

Defaults to the [zlib-ng](https://github.com/zlib-ng/zlib-ng) backend for up to 2.5x faster compression. Standard zlib is also available via `backend=GZip.ZLIB`.

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

Both packages use zlib under the hood but serve different use cases:

| | GZip.jl | CodecZlib.jl |
|:---|:---|:---|
| **Best for** | File-based gzip I/O | In-memory compression, streaming pipelines |
| **API style** | Drop-in `IO` replacement (`read`, `write`, `seek`) | TranscodingStreams (`transcode`, composable codecs) |
| **zlib-ng support** | Yes (default backend) | No |
| **Seeking** | Yes | No |
| **In-memory compress/decompress** | No | Yes (`transcode`) |
| **Raw deflate/zlib format** | No (gzip only) | Yes |
| **Header metadata** | Yes (`gzheader`) | No |

**Use GZip.jl** when you need file-oriented gzip I/O with seeking, zlib-ng performance, or header metadata access.

**Use [ChunkCodecLibZlib.jl](https://github.com/JuliaIO/ChunkCodecs.jl/tree/main/LibZlib)** when you need one-shot in-memory compression with configurable compression level and output size hints.

## Documentation

See the [full documentation](https://juliaio.github.io/GZip.jl/dev) for details, including benchmarks.
