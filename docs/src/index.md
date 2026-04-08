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

## zlib-ng Backend

[zlib-ng](https://github.com/zlib-ng/zlib-ng) is a high-performance fork of zlib
with optimized implementations for modern CPUs. GZip.jl supports it as an
alternative backend.

```julia
using GZip

# Use zlib-ng for writing
GZip.open("data.gz", "w"; backend=GZip.ZLIBNG) do io
    write(io, "compressed with zlib-ng")
end

# Use zlib-ng for reading
data = GZip.open(read, "data.gz"; backend=GZip.ZLIBNG)
```

Files produced by either backend are standard gzip files and can be read by
any gzip implementation, including the other backend:

```julia
# Write with zlib-ng, read with zlib (or vice versa)
GZip.open("data.gz", "w"; backend=GZip.ZLIBNG) do io
    write(io, "hello")
end
data = GZip.open(read, "data.gz")  # default zlib backend
```

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

`seekend` and `truncate` are not available due to limitations in zlib.

## Notes

- This interface is for gzipped files only, not the streaming zlib compression interface.
- `GZipStream` is a subtype of `IO` and can be used anywhere `IO` is accepted.
- `readline` strips trailing newlines by default (`keep=false`), matching `Base.readline`.
