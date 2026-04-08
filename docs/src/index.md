# GZip.jl

A Julia interface for gzip functions in [zlib](http://zlib.net), a free,
general-purpose, legally unencumbered, lossless data-compression library.

GZip.jl provides `GZipStream`, a drop-in `IO` replacement for reading and
writing gzip (`.gz`) files. It supports both standard zlib and
[zlib-ng](https://github.com/zlib-ng/zlib-ng) backends.

## Installation

```julia
using Pkg
Pkg.add("GZip")
```

## Basic Usage

### Writing

```julia
using GZip

GZip.open("output.gz", "w") do io
    write(io, "hello world\n")
    println(io, "another line")
end
```

### Reading

```julia
# Read entire file as a string
data = GZip.open(read, "output.gz")

# Read line by line
GZip.open("output.gz") do io
    for line in eachline(io)
        println(line)
    end
end
```

### Reading and Writing Arrays

```julia
# Write an array
a = rand(Float64, 1000)
GZip.open("array.gz", "w") do io
    write(io, a)
end

# Read it back
b = zeros(Float64, 1000)
GZip.open("array.gz") do io
    read(io, b)
end
```

### Compression Levels

The mode string accepts a compression level (0-9) and strategy flags:

```julia
# Fast compression
GZip.open("fast.gz", "wb1") do io
    write(io, data)
end

# Best compression
GZip.open("small.gz", "wb9") do io
    write(io, data)
end
```

## Backends: zlib-ng and zlib

GZip.jl defaults to [zlib-ng](https://github.com/zlib-ng/zlib-ng), a high-performance
fork of zlib with optimized implementations for modern CPUs. The standard zlib
backend is also available.

```julia
using GZip

# Default (zlib-ng)
GZip.open("data.gz", "w") do io
    write(io, "compressed with zlib-ng")
end

# Explicitly use standard zlib
GZip.open("data.gz", "w"; backend=GZip.ZLIB) do io
    write(io, "compressed with zlib")
end
```

Files produced by either backend are standard gzip files and can be read by
any gzip implementation, including the other backend:

```julia
# Write with zlib-ng, read with zlib (or vice versa)
GZip.open("data.gz", "w") do io
    write(io, "hello")
end
data = GZip.open(read, "data.gz"; backend=GZip.ZLIB)
```

### Benchmarks

zlib 1.3.1 vs zlib-ng 2.3.2, Julia 1.12.5, Linux x86_64 (AMD EPYC 7513).

**enwik9 (1GB Wikipedia XML, compression ratio 3.09x):**

| Benchmark | zlib | zlib-ng | Speedup |
|:---|:---|:---|:---|
| write (level=1) | 93 MB/s | 229 MB/s | **2.46x** |
| write (level=6) | 27 MB/s | 69 MB/s | **2.54x** |
| write (level=9) | 21 MB/s | 32 MB/s | **1.50x** |
| read | 225 MB/s | 366 MB/s | **1.62x** |
| roundtrip (level=1) | 66 MB/s | 136 MB/s | **2.07x** |
| roundtrip (level=6) | 24 MB/s | 57 MB/s | **2.37x** |
| roundtrip (level=9) | 20 MB/s | 29 MB/s | **1.51x** |

**Silesia corpus (55MB mixed data):**

| Benchmark | zlib | zlib-ng | Speedup |
|:---|:---|:---|:---|
| write (level=1) | 46 MB/s | 98 MB/s | **2.14x** |
| read | 454 MB/s | 512 MB/s | **1.13x** |
| roundtrip (level=1) | 42 MB/s | 69 MB/s | **1.65x** |

Run benchmarks yourself with `julia --project=. test/benchmarks.jl` (see `test/README.md`).

## Supported IO Functions

`GZipStream` implements the `IO` interface. The following functions are supported:

| Function      | Description                          |
|:--------------|:-------------------------------------|
| `close`       | Close the stream                     |
| `flush`       | Flush pending output                 |
| `seek`        | Seek to byte position                |
| `skip`        | Skip bytes                           |
| `position`    | Current position in uncompressed stream |
| `eof`         | Check for end of file                |
| `read`        | Read data                            |
| `readuntil`   | Read until delimiter                 |
| `readline`    | Read a line                          |
| `write`       | Write data                           |
| `peek`        | Peek at next byte                    |
| `isreadable`  | Check if stream is open for reading  |
| `iswritable`  | Check if stream is open for writing  |

`seekend` and `truncate` are not available due to limitations in zlib.

## In-memory compression

GZip.jl is designed for file-based gzip I/O. For one-shot in-memory compression
and decompression (like Python's `gzip.compress()` / `gzip.decompress()`), use
[CodecZlib.jl](https://github.com/JuliaIO/CodecZlib.jl) which wraps zlib's
streaming `deflate`/`inflate` API:

```julia
using CodecZlib
compressed = transcode(GzipCompressor, data)
decompressed = transcode(GzipDecompressor, compressed)
```

## Notes

- This interface is for gzipped files only, not the streaming zlib compression interface.
- `GZipStream` is a subtype of `IO` and can be used anywhere `IO` is accepted.
- `readline` strips trailing newlines by default (`keep=false`), matching `Base.readline`.
