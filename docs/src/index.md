# GZip.jl

A Julia interface for gzip functions in [zlib](http://zlib.net), a free,
general-purpose, legally unencumbered, lossless data-compression library.

GZip.jl provides `GZipStream`, a drop-in `IO` replacement for reading and
writing gzip (`.gz`) files. It defaults to the high-performance
[zlib-ng](https://github.com/zlib-ng/zlib-ng) backend; standard zlib is
also available via `backend=GZip.ZLIB`.

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

## Header Metadata

[`gzheader`](@ref) reads gzip header fields (RFC 1952) without decompressing:

```julia
h = gzheader("data.gz")
h.name     # original filename, or nothing
h.mtime    # modification time as Unix timestamp (0 = not set)
h.comment  # file comment, or nothing
h.os       # OS identifier (0x03 = Unix)
h.extra    # extra field data, or nothing
h.is_text  # hint that content is ASCII text
```

!!! note
    Files created by GZip.jl (via zlib/zlib-ng) will have `name=nothing` and
    `mtime=0`, because the zlib `gzopen` API does not set these header fields.
    Files created by command-line `gzip` typically include the original filename
    and modification time.

## File Descriptor I/O

[`gzdopen`](@ref) wraps an existing file descriptor as a gzip stream:

```julia
# Wrap an open IOStream's file descriptor
raw = open("data.gz", "r")
gz = gzdopen(fd(raw), "r")
data = read(gz, String)
close(gz)
close(raw)
```

`gzdopen` duplicates the file descriptor internally, so closing the
`GZipStream` does not close the original.

## Error Handling

GZip.jl throws three exception types:

- [`GZError`](@ref) — gzip-level errors (corrupt data, stream errors). Contains
  an error code (`err`) and message (`err_str`).
- [`ZError`](@ref) — zlib-level errors (version mismatch, memory). Same fields.
- `SystemError` — OS-level errors (file not found, bad file descriptor).

```julia
try
    gzopen("missing.gz") do io
        read(io, String)
    end
catch e
    if e isa SystemError
        # file not found, permission denied, etc.
    elseif e isa GZError
        # corrupt gzip data, CRC mismatch, etc.
        println("gzip error $(e.err): $(e.err_str)")
    end
end
```

Corrupt data is typically detected on `read` or `close` (CRC check happens
at stream close).

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

zlib 1.3.1 vs zlib-ng 2.3.3, Julia 1.12.5, Linux x86_64 (AMD EPYC 7513).

**enwik9 (1GB Wikipedia XML, compression ratio 3.09x):**

| Benchmark | zlib | zlib-ng | Speedup |
|:---|:---|:---|:---|
| write (level=1) | 92 MB/s | 231 MB/s | **2.52x** |
| write (level=9) | 21 MB/s | 33 MB/s | **1.56x** |
| read | 296 MB/s | 656 MB/s | **2.22x** |
| roundtrip (level=1) | 67 MB/s | 144 MB/s | **2.16x** |
| roundtrip (level=9) | 19 MB/s | 31 MB/s | **1.61x** |

**Silesia corpus (55MB mixed data):**

| Benchmark | zlib | zlib-ng | Speedup |
|:---|:---|:---|:---|
| write (level=1) | 46 MB/s | 97 MB/s | **2.13x** |
| write (level=9) | 44 MB/s | 47 MB/s | **1.08x** |
| read | 1041 MB/s | 1575 MB/s | **1.51x** |
| roundtrip (level=1) | 42 MB/s | 75 MB/s | **1.76x** |
| roundtrip (level=9) | 42 MB/s | 45 MB/s | **1.08x** |

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
[ChunkCodecLibZlib.jl](https://github.com/JuliaIO/ChunkCodecs.jl/tree/main/LibZlib)
which supports setting compression level and output size hints:

```julia
using ChunkCodecLibZlib
compressed = encode(ZlibCompressCodec(), data)
decompressed = decode(ZlibDecompressCodec(), compressed)
```

## Notes

- This interface is for gzipped files only, not the streaming zlib compression interface.
- `GZipStream` is a subtype of `IO` and can be used anywhere `IO` is accepted.
- `readline` strips trailing newlines by default (`keep=false`), matching `Base.readline`.
