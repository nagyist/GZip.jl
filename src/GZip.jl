## gzip file io

"""
GZip.jl: A Julia interface for gzip functions in zlib

This module provides a wrapper for the gzip related functions of
([zlib](http://zlib.net/)), a free, general-purpose, legally
unencumbered, lossless data-compression library. These functions allow
the reading and writing of gzip files.

Defaults to the [zlib-ng](https://github.com/zlib-ng/zlib-ng) backend for
faster compression and decompression. Use `backend=GZip.ZLIB` to use standard
zlib instead. Files are cross-compatible between backends.

## Notes

-   This interface is only for gzipped files, not the streaming zlib
    compression interface. Internally, it depends on/uses the
    streaming interface, but the gzip related functions are higher
    level functions pertaining to gzip files only.
-   `GZipStream` is an implementation of `IO` and can be used virtually
    anywhere `IO` is used.
-   This implementation mimics the `IOStream` implementation, and should be a
    drop-in replacement for `IOStream`, with some caveats:
    -   `seekend` and `truncate` are not available
    -   `readuntil` is available, but is not very efficient. (But `readline` works fine.)

In addition to [`open`](@ref), [`gzopen`](@ref), and [`gzdopen`](@ref), the
following `IO`/`IOStream` functions are supported:

-   `close()`
-   `flush()`
-   `seek()`
-   `skip()`
-   `position()`
-   `eof()`
-   `read()`
-   `readuntil()`
-   `readline()`
-   `write()`
-   `peek()`
-   `isreadable()`
-   `iswritable()`

[`gzheader`](@ref) reads gzip header metadata without decompressing.

Due to limitations in `zlib`, `seekend` and `truncate` are not available.
"""
module GZip

using Base.Libc

import Base: show, fd, close, flush, truncate, seek,
             seekend, skip, position, eof, read,
             readline, write, unsafe_read, unsafe_write, peek,
             isopen, isreadable, iswritable,
             bytesavailable, readavailable, readbytes!

export
  GZipStream,

# Backend types
  GZBackend,
  ZlibBackend,
  ZlibNGBackend,
  ZLIB,
  ZLIBNG,

# IO functions (open is not exported; use GZip.open)
  gzopen,
  gzdopen,

# Errors
  GZError,
  ZError,

# Header metadata
  GZipHeader,
  gzheader

# Not exported but accessible via GZip.X:
#   Z_OK, Z_STREAM_END, Z_ERRNO, ... (error codes)
#   Z_NO_COMPRESSION, Z_BEST_SPEED, ... (compression levels)
#   Z_FILTERED, Z_HUFFMAN_ONLY, ...     (strategies)
#   Z_DEFAULT_BUFSIZE, Z_BIG_BUFSIZE    (buffer sizes)
#   ZFileOffset                          (offset type alias)
#   gzgetc, gzungetc, gzgets, ...       (low-level C wrappers)

include("zlib.jl")
include("gz.jl")

end # module GZip
