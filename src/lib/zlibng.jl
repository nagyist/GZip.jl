module ZlibNG_h

using ZlibNG_jll
export ZlibNG_jll

function zng_zlibCompileFlags()
    ccall((:zng_zlibCompileFlags, ZlibNG_jll.libzng_path), Culong, ())
end

# zlib-ng native API: z_off64_t (used by gzseek/gztell/gzoffset and gzFile_s.pos)
# - Linux (all): Int64 (off64_t via _LARGEFILE64_SOURCE)
# - macOS: Int64 (off_t is always 64-bit)
# - Windows (all): Int32 (z_off64_t = z_off64_t = long, which is 32-bit on LLP64)
const z_off64_t = Sys.iswindows() ? Int32 : Int64

struct gzFile_s
    have::Cuint
    next::Ptr{Cuchar}
    pos::z_off64_t
end

const gzFile = Ptr{gzFile_s}

function zng_gzopen(path, mode)
    ccall((:zng_gzopen, ZlibNG_jll.libzng_path), gzFile, (Ptr{Cchar}, Ptr{Cchar}), path, mode)
end

function zng_gzdopen(fd::Cint, mode)
    ccall((:zng_gzdopen, ZlibNG_jll.libzng_path), gzFile, (Cint, Ptr{Cchar}), fd, mode)
end

function zng_gzbuffer(file::gzFile, size::UInt32)
    ccall((:zng_gzbuffer, ZlibNG_jll.libzng_path), Int32, (gzFile, UInt32), file, size)
end

function zng_gzread(file::gzFile, buf, len::UInt32)
    ccall((:zng_gzread, ZlibNG_jll.libzng_path), Int32, (gzFile, Ptr{Cvoid}, UInt32), file, buf, len)
end

function zng_gzfread(buf, size::Csize_t, nitems::Csize_t, file::gzFile)
    ccall((:zng_gzfread, ZlibNG_jll.libzng_path), Csize_t, (Ptr{Cvoid}, Csize_t, Csize_t, gzFile), buf, size, nitems, file)
end

function zng_gzwrite(file::gzFile, buf, len::UInt32)
    ccall((:zng_gzwrite, ZlibNG_jll.libzng_path), Int32, (gzFile, Ptr{Cvoid}, UInt32), file, buf, len)
end

function zng_gzfwrite(buf, size::Csize_t, nitems::Csize_t, file::gzFile)
    ccall((:zng_gzfwrite, ZlibNG_jll.libzng_path), Csize_t, (Ptr{Cvoid}, Csize_t, Csize_t, gzFile), buf, size, nitems, file)
end

function zng_gzgets(file::gzFile, buf, len::Int32)
    ccall((:zng_gzgets, ZlibNG_jll.libzng_path), Ptr{Cchar}, (gzFile, Ptr{Cchar}, Int32), file, buf, len)
end

function zng_gzputc(file::gzFile, c::Int32)
    ccall((:zng_gzputc, ZlibNG_jll.libzng_path), Int32, (gzFile, Int32), file, c)
end

function zng_gzungetc(c::Int32, file::gzFile)
    ccall((:zng_gzungetc, ZlibNG_jll.libzng_path), Int32, (Int32, gzFile), c, file)
end

function zng_gzflush(file::gzFile, flush::Int32)
    ccall((:zng_gzflush, ZlibNG_jll.libzng_path), Int32, (gzFile, Int32), file, flush)
end

function zng_gzseek(file::gzFile, offset::z_off64_t, whence::Cint)
    ccall((:zng_gzseek, ZlibNG_jll.libzng_path), z_off64_t, (gzFile, z_off64_t, Cint), file, offset, whence)
end

function zng_gzrewind(file::gzFile)
    ccall((:zng_gzrewind, ZlibNG_jll.libzng_path), Int32, (gzFile,), file)
end

function zng_gztell(file::gzFile)
    ccall((:zng_gztell, ZlibNG_jll.libzng_path), z_off64_t, (gzFile,), file)
end

function zng_gzoffset(file::gzFile)
    ccall((:zng_gzoffset, ZlibNG_jll.libzng_path), z_off64_t, (gzFile,), file)
end

function zng_gzeof(file::gzFile)
    ccall((:zng_gzeof, ZlibNG_jll.libzng_path), Int32, (gzFile,), file)
end

function zng_gzdirect(file::gzFile)
    ccall((:zng_gzdirect, ZlibNG_jll.libzng_path), Int32, (gzFile,), file)
end

function zng_gzclose(file::gzFile)
    ccall((:zng_gzclose, ZlibNG_jll.libzng_path), Int32, (gzFile,), file)
end

function zng_gzerror(file::gzFile, errnum)
    ccall((:zng_gzerror, ZlibNG_jll.libzng_path), Ptr{Cchar}, (gzFile, Ptr{Int32}), file, errnum)
end

function zng_zError(arg1::Int32)
    ccall((:zng_zError, ZlibNG_jll.libzng_path), Ptr{Cchar}, (Int32,), arg1)
end

function zlibng_version()
    ccall((:zlibng_version, ZlibNG_jll.libzng_path), Ptr{Cchar}, ())
end

end # module
