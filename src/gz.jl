# Expected line length for strings
const GZ_LINE_BUFSIZE = 256

# Constants for use with gzseek
const SEEK_SET =  Cint(0)
const SEEK_CUR =  Cint(1)

# Wrapper around gzFile
"""
    GZipStream <: IO

    GZipStream(name, gz_file, [buf_size]; backend=ZLIB)

Subtype of `IO` which wraps a gzip stream. Returned by [`gzopen`](@ref) and
[`gzdopen`](@ref). Parameterized by the backend (`ZlibBackend` or `ZlibNGBackend`).
"""
mutable struct GZipStream{B<:GZBackend} <: IO
    name::AbstractString
    gz_file::GZFile
    buf_size::Int
    backend::B
    _closed::Bool

    function GZipStream(name::AbstractString, gz_file::GZFile, buf_size::Int, backend::B) where {B<:GZBackend}
        x = new{B}(name, gz_file, buf_size, backend, false)
        finalizer(close, x)
        x
    end
end

# gzerror
function gzerror(err::Integer, s::GZipStream)
    e = Cint[err]
    if !s._closed
        msg_p = gz_error(s.backend, s.gz_file, e)
        msg = (msg_p == C_NULL ? "" : unsafe_string(msg_p))
    else
        msg = "(GZipStream closed)"
    end
    (e[1], msg)
end
gzerror(s::GZipStream) = gzerror(0, s)

"""
    GZError <: Exception

gzip error number and string. Possible error values:

| Error number         | String                                                    |
|:---------------------|:----------------------------------------------------------|
|  `Z_OK`              |  No error                                                 |
|  `Z_ERRNO`           |  Filesystem error (consult `errno()`)                     |
|  `Z_STREAM_ERROR`    |  Inconsistent stream state                                |
|  `Z_DATA_ERROR`      |  Compressed data error                                    |
|  `Z_MEM_ERROR`       |  Out of memory                                            |
|  `Z_BUF_ERROR`       |  Input buffer full/output buffer empty                    |
|  `Z_VERSION_ERROR`   |  zlib library version is incompatible with caller version |
"""
mutable struct GZError <: Exception
    err::Int32
    err_str::AbstractString

    GZError(e::Integer, str::AbstractString) = new(Int32(e), str)
    GZError(e::Integer, s::GZipStream) = (a = gzerror(e, s); new(a[1], a[2]))
    GZError(s::GZipStream) = (a = gzerror(s); new(a[1], a[2]))
end

# ZError constructor needs backend for gz_zerror dispatch
ZError(e::Integer, backend::GZBackend=ZLIB) = (e == Z_ERRNO ? ZError(e, strerror()) : ZError(e, gz_zerror(backend, e)))

# show
show(io::IO, s::GZipStream) = print(io, "GZipStream(", s.name, ")")

macro test_eof_gzerr(s, cc, val)
    quote
        if $(esc(s))._closed throw(EOFError()) end
        ret = $(esc(cc))
        if ret == $(esc(val))
            if eof($(esc(s)))  throw(EOFError())  else  throw(GZError($(esc(s))))  end
        end
        ret
    end
end

macro test_eof_gzerr2(s, cc, val)
    quote
        if $(esc(s))._closed throw(EOFError()) end
        ret = $(esc(cc))
        if ret == $(esc(val)) && !eof($(esc(s))) throw(GZError($(esc(s)))) end
        ret
    end
end

macro test_gzerror(s, cc, val)
    quote
        if $(esc(s))._closed throw(EOFError()) end
        ret = $(esc(cc))
        if ret == $(esc(val)) throw(GZError(ret, $(esc(s)))) end
        ret
    end
end

macro test_gzerror0(s, cc)
    quote
        if $(esc(s))._closed throw(EOFError()) end
        ret = $(esc(cc))
        if ret <= 0 throw(GZError(ret, $(esc(s)))) end
        ret
    end
end

macro test_z_ok(s, cc)
    quote
        ret = $(esc(cc))
        if (ret != Z_OK) throw(ZError(ret, $(esc(s)).backend)) end
        ret
    end
end

"""
    gzgetc(s::GZipStream)

Read a single byte from the stream. Throws `EOFError` at end of file.
"""
gzgetc(s::GZipStream) = @test_eof_gzerr(s, gz_getc(s.backend, s.gz_file), -1)

gzgetc_raw(s::GZipStream) = gz_getc(s.backend, s.gz_file)

"""
    gzungetc(c::Integer, s::GZipStream)

Push a byte back onto the stream for subsequent reading.
"""
gzungetc(c::Integer, s::GZipStream) = @test_eof_gzerr(s, gz_ungetc(s.backend, c, s.gz_file), -1)

"""
    gzgets(s::GZipStream, buf)

Read a line from the stream into `buf`, stopping at newline or end of file.
"""
gzgets(s::GZipStream, a::Array{UInt8}) =
    @test_eof_gzerr2(s, gz_gets(s.backend, s.gz_file, a, Cint(length(a))), C_NULL)

gzgets(s::GZipStream, p::Ptr{UInt8}, len::Integer) =
    @test_eof_gzerr2(s, gz_gets(s.backend, s.gz_file, p, Cint(len)), C_NULL)

"""
    gzputc(s::GZipStream, c::Integer)

Write a single byte to the stream.
"""
gzputc(s::GZipStream, c::Integer) = @test_gzerror(s, gz_putc(s.backend, s.gz_file, Cint(c)), -1)

"""
    gzwrite(s::GZipStream, p::Ptr, len::Integer)

Write `len` bytes from pointer `p` to the stream. Returns the number of bytes written.
"""
gzwrite(s::GZipStream, p::Ptr, len::Integer) =
    len == 0 ? Cint(0) : @test_gzerror0(s, gz_write(s.backend, s.gz_file, reinterpret(Ptr{Cvoid}, p), Cuint(len)))

"""
    gzread(s::GZipStream, p::Ptr, len::Integer)

Read `len` bytes from the stream into the buffer at pointer `p`. Returns the number of bytes read.
"""
gzread(s::GZipStream, p::Ptr, len::Integer) =
    @test_gzerror(s, gz_read(s.backend, s.gz_file, reinterpret(Ptr{Cvoid}, p), Cuint(len)), -1)

"""
    gzbuffer(backend::GZBackend, gz_file, gz_buf_size::Integer)

Set the internal buffer size for the gzip file. Must be called before any read or write.
"""
gzbuffer(backend::GZBackend, gz_file::GZFile, gz_buf_size::Integer) = gz_buffer(backend, gz_file, gz_buf_size)

#####

"""
    gzopen(fname::AbstractString, [gzmode::AbstractString, buf_size::Integer]; backend=ZLIB)::GZipStream

Opens a file with mode (default `"r"`), setting internal buffer size to
buf\\_size (default `Z_DEFAULT_BUFSIZE=8192`), and returns a the file as a
`GZipStream`.

`gzmode` must contain one of:

| mode | Description             |
|:-----|:------------------------|
| r    | read                    |
| w    | write, create, truncate |
| a    | write, create, append   |

In addition, gzmode may also contain

| mode | Description                                        |
|:-----|:---------------------------------------------------|
| x    | create the file exclusively (fails if file exists) |
| 0-9  | compression level                                  |

and/or a compression strategy:

| mode | Description             |
|:-----|:------------------------|
| f    | filtered data            |
| h    | Huffman-only compression |
| R    | run-length encoding      |
| F    | fixed code compression   |

Note that `+` is not allowed in `gzmode`. If an error occurs, `gzopen` throws a [`GZError`](@ref).

Use `backend=GZip.ZLIBNG` to use the zlib-ng backend instead of the default zlib.
"""
function gzopen(fname::AbstractString, gzmode::AbstractString, gz_buf_size::Integer;
                backend::GZBackend=ZLIB)
    # For windows, force binary mode; doesn't hurt on unix
    if !('b' in gzmode)
        gzmode *= "b"
    end

    gz_file = gz_open(backend, fname, gzmode)
    if gz_file == C_NULL
        errno = Libc.errno()
        throw(SystemError("$(fname)", errno))
    end
    if gz_buf_size != Z_DEFAULT_BUFSIZE
        if gzbuffer(backend, gz_file, gz_buf_size) == -1
            gz_buf_size = Z_DEFAULT_BUFSIZE
        end
    end
    s = GZipStream(fname, gz_file, gz_buf_size, backend)
    peek(s) # Set EOF-bit for empty files
    return s
end
gzopen(fname::AbstractString, gzmode::AbstractString; backend::GZBackend=ZLIB) = gzopen(fname, gzmode, Z_DEFAULT_BUFSIZE; backend)
gzopen(fname::AbstractString; backend::GZBackend=ZLIB) = gzopen(fname, "rb", Z_DEFAULT_BUFSIZE; backend)

"""
    open(fname::AbstractString, [gzmode, bufsize]; backend=ZLIB)::GZipStream

Alias for [`gzopen`](@ref). This is not exported, and must be called using `GZip.open`.
"""
open(args...; kwargs...) = gzopen(args...; kwargs...)

function gzopen(f::Function, args...; kwargs...)
    io = gzopen(args...; kwargs...)
    try f(io)
    finally close(io)
    end
end

"""
    gzdopen(fd, [gzmode, buf_size]; backend=ZLIB)

Create a `GZipStream` object from an integer file descriptor.
See [`gzopen`](@ref) for `gzmode` and `buf_size` descriptions.
"""
function gzdopen(name::AbstractString, fd::Integer, gzmode::AbstractString, gz_buf_size::Integer;
                 backend::GZBackend=ZLIB)
    if !('b' in gzmode)
        gzmode *= "b"
    end

    # Duplicate the file descriptor, since we have no way to tell gzclose()
    # not to close the original fd
    dup_fd = Libc.dup(Libc.RawFD(fd))

    gz_file = gz_dopen(backend, reinterpret(Cint, dup_fd), gzmode)
    if gz_file == C_NULL
        errno = Libc.errno()
        throw(SystemError("$(name)", errno))
    end
    if gz_buf_size != Z_DEFAULT_BUFSIZE
        if gzbuffer(backend, gz_file, gz_buf_size) == -1
            gz_buf_size = Z_DEFAULT_BUFSIZE
        end
    end
    s = GZipStream(name, gz_file, gz_buf_size, backend)
    peek(s) # Set EOF-bit for empty files
    return s
end
gzdopen(fd::Integer, gzmode::AbstractString, gz_buf_size::Integer; backend::GZBackend=ZLIB) = gzdopen(string("<fd ",fd,">"), fd, gzmode, gz_buf_size; backend)
gzdopen(fd::Integer, gz_buf_size::Integer; backend::GZBackend=ZLIB) = gzdopen(fd, "rb", gz_buf_size; backend)
gzdopen(fd::Integer, gzmode::AbstractString; backend::GZBackend=ZLIB) = gzdopen(fd, gzmode, Z_DEFAULT_BUFSIZE; backend)
gzdopen(fd::Integer; backend::GZBackend=ZLIB) = gzdopen(fd, "rb", Z_DEFAULT_BUFSIZE; backend)
gzdopen(fd::RawFD, args...; kwargs...) = gzdopen(Base.cconvert(Cint, fd), args...; kwargs...)
gzdopen(s::IOStream, args...; kwargs...) = gzdopen(fd(s), args...; kwargs...)


fd(s::GZipStream) = error("fd is not supported for GZipStreams")

function close(s::GZipStream)
    if s._closed
        return Z_STREAM_ERROR
    end
    s._closed = true

    s.name *= " (closed)"

    ret = (@test_z_ok s gz_close(s.backend, s.gz_file))

    return ret
end

flush(s::GZipStream, fl::Integer) =
    @test_z_ok s gz_flush(s.backend, s.gz_file, Cint(fl))
flush(s::GZipStream) = flush(s, Z_SYNC_FLUSH)

truncate(s::GZipStream, n::Integer) = throw(MethodError(truncate, (GZipStream, Integer)))

# Note: seeks to byte position within uncompressed data stream
function seek(s::GZipStream, n::Integer)
    gz_seek(s.backend, s.gz_file, n, SEEK_SET) != -1 || error("seek (gzseek) failed")
end

# Note: skips bytes within uncompressed data stream
# Mimic behavior of skip(s::IOStream, n)
skip(s::GZipStream, n::Integer) =
    gz_seek(s.backend, s.gz_file, n, SEEK_CUR) != -1 || error("skip (gzseek) failed")

position(s::GZipStream, raw::Bool=false) = raw ? gz_offset(s.backend, s.gz_file) : gz_tell(s.backend, s.gz_file)

eof(s::GZipStream) = Bool(gz_eof(s.backend, s.gz_file))

function peek(s::GZipStream)
    c = gzgetc_raw(s)
    if c != -1
        gzungetc(c, s)
    end
    c
end

# Mimics read(s::IOStream, a::Array{T})
function read(s::GZipStream, a::Array{T}) where {T}
    if isbitstype(T)
        nb = length(a)*sizeof(T)
        # Note: this will overflow and succeed without warning if nb > 4GB
        ret = gz_read(s.backend, s.gz_file, reinterpret(Ptr{Cvoid}, pointer(a)), Cuint(nb))
        if ret == -1
            throw(GZError(s))
        end
        if ret < nb
            throw(EOFError())
        end
        peek(s) # force eof to be set
        a
    else
        invoke(read!, Tuple{IO,Array}, s, a)
    end
end

function read(s::GZipStream, ::Type{UInt8})
    ret = gzgetc(s)
    if ret == -1
        throw(GZError(s))
    end
    peek(s) # force eof to be set
    UInt8(ret)
end


function read(s::GZipStream; bufsize::Int = Z_BIG_BUFSIZE)
    buf = Array{UInt8}(undef, bufsize)
    len = 0
    while true
        ret = gzread(s, pointer(buf)+len, bufsize)
        if ret == 0
            if length(buf) > len
                resize!(buf, len)
            end
            return buf
        end
        len += ret
        resize!(buf, bufsize+len)
    end
end

# For this function, it's really unfortunate that zlib is
# not integrated with ios
function read(s::GZipStream, ::Type{String}; bufsize::Int = Z_BIG_BUFSIZE)
    buf = Array{UInt8}(undef, bufsize)
    len = 0
    while true
        ret = gzread(s, pointer(buf)+len, bufsize)
        if ret == 0
            if length(buf) > len
                resize!(buf, len)
            end
            return String(copy(buf))
        end
        len += ret
        # Grow the buffer so that bufsize bytes will fit
        resize!(buf, bufsize+len)
    end
end

function readline(s::GZipStream; keep::Bool=false)
    buf = Array{UInt8}(undef, GZ_LINE_BUFSIZE)
    pos = 1

    if gzgets(s, buf) == C_NULL      # Throws an exception on error
        return ""
    end

    while(true)
        # since gzgets didn't return C_NULL, there must be a \0 in the buffer
        eos = findnext(x->x==UInt8('\0'), buf, pos)::Int
        if eos == 1 || buf[eos-1] == UInt8('\n')
            endpos = eos - 1
            if !keep && endpos >= 1 && buf[endpos] == UInt8('\n')
                endpos -= 1
                if endpos >= 1 && buf[endpos] == UInt8('\r')
                    endpos -= 1
                end
            end
            return String(copy(resize!(buf, endpos)))
        end

        # If we're at the end of the file, return the string
        if eof(s)
            return String(copy(resize!(buf, eos-1)))
        end

        # Otherwise, append to the end of the previous buffer

        # Grow the buffer so that there's room for GZ_LINE_BUFSIZE chars
        add_len = GZ_LINE_BUFSIZE - (length(buf)-eos+1)
        resize!(buf, add_len+length(buf))
        pos = eos

        # Read in the next chunk
        if gzgets(s, pointer(buf)+pos-1, GZ_LINE_BUFSIZE) == C_NULL
            # eof(s); remove extra buffer space
            return String(copy(resize!(buf, length(buf)-add_len)))
        end
    end
end

write(s::GZipStream, b::UInt8) = (gzputc(s, b); 1)
write(s::GZipStream, a::Array{UInt8}) = Int(gzwrite(s, pointer(a), sizeof(a)))
unsafe_write(s::GZipStream, p::Ptr{UInt8}, nb::UInt) = Int(gzwrite(s, p, nb))
