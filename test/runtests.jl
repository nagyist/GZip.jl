using GZip
using Test

test_infile = @__FILE__

@static if Sys.iswindows()
    gunzip = "gunzip.exe"
elseif Sys.isunix()
    gunzip = "gunzip"
end

test_gunzip = true
try
    run(pipeline(`which $gunzip`, devnull))
catch
    global test_gunzip
    test_gunzip = false
end

function run_backend_tests(; backend=GZip.ZLIB)
    tmp = mktempdir()
    test_compressed = joinpath(tmp, "runtests.jl.gz")
    test_empty = joinpath(tmp, "empty.jl.gz")

    try

    @testset "Compress and decompress" begin
        data = open(x->read(x, String), test_infile);

        first_char = data[1]

        gzfile = gzopen(test_compressed, "wb"; backend)
        @test write(gzfile, data) == sizeof(data)
        @test close(gzfile) == Z_OK
        @test close(gzfile) != Z_OK

        @test_throws EOFError write(gzfile, data)

        if test_gunzip
            data2 = read(`$gunzip -c $test_compressed`, String)
            @test data == data2
        end

        data3 = gzopen(x->read(x, String), test_compressed; backend)
        @test data == data3

        # Test gzfdio
        @test_throws "No such file or directory" gzopen("wrong_file.gz", "r"; backend)
        @test_throws "Bad file descriptor" gzdopen("wrong_fd.gz", -1, "r", 1024; backend)

        raw_file = open(test_compressed, "r")
        gzfile = gzdopen(fd(raw_file), "r"; backend)
        data4 = read(gzfile, String)
        close(gzfile)
        close(raw_file)
        @test data == data4

        # Test peek
        gzfile = gzopen(test_compressed, "r"; backend)
        @test peek(gzfile) == UInt(first_char)
        read(gzfile, String)
        @test peek(gzfile) == -1
        close(gzfile)

        # Corrupt header (leave the gzip magic 2-byte header intact)
        raw_file = open(test_compressed, "r+")
        seek(raw_file, 3)
        write(raw_file, zeros(UInt8, 10))
        close(raw_file)

        @test_throws Union{ArgumentError,ZError,GZError} gzopen(x->read(x, String), test_compressed; backend)
    end

    @testset "readbytes!" begin
        gzopen(test_compressed, "w"; backend) do io
            write(io, "hello world")
        end
        gzopen(test_compressed; backend) do io
            buf = Vector{UInt8}(undef, 5)
            @test readbytes!(io, buf) == 5
            @test buf == b"hello"
            buf2 = Vector{UInt8}(undef, 100)
            @test readbytes!(io, buf2) == 6
            @test buf2[1:6] == b" world"
        end
    end

    @testset "readline keep keyword" begin
        gzopen(test_compressed, "w"; backend) do io
            write(io, "line1\nline2\nline3")
        end

        # Default (keep=false) should strip newlines
        gzopen(test_compressed; backend) do io
            @test readline(io) == "line1"
            @test readline(io) == "line2"
            @test readline(io) == "line3"
        end

        # keep=true should preserve newlines
        gzopen(test_compressed; backend) do io
            @test readline(io; keep=true) == "line1\n"
            @test readline(io; keep=true) == "line2\n"
            @test readline(io; keep=true) == "line3"
        end
    end

    @testset "Writing" begin
        data = open(x->read(x, String), test_infile);

        gzfile = gzopen(test_compressed, "wb"; backend)
        @test write(gzfile, data) == sizeof(data)
        @test flush(gzfile) == Z_OK

        NEW = GZip.ZLIB_VERSION >= (1, 2, 4)
        pos = position(gzfile)
        NEW && (pos2 = position(gzfile,true))
        @test_throws ErrorException seek(gzfile, 0)   # can't seek backwards on write
        @test position(gzfile) == pos
        NEW && (@test position(gzfile,true) == pos2)
        @test skip(gzfile, 100)
        @test position(gzfile) == pos + 100
        NEW && (@test position(gzfile,true) == pos2)

        @test_throws MethodError truncate(gzfile, 100)
        @test_throws MethodError seekend(gzfile)

        @test close(gzfile) == Z_OK

        gzopen(test_empty, "w"; backend) do io
            a = UInt8[]
            @test gzwrite(io, pointer(a), length(a)*sizeof(eltype(a))) == Int32(0)
        end

        # write(::GZipStream, ::UInt8) should return 1 (byte count, not value)
        gzopen(test_compressed, "w"; backend) do io
            @test write(io, 0x0a) == 1
            @test write(io, 0xff) == 1
        end

        # Test writing SubArrays (views)
        gzfile = gzopen(test_compressed, "wb"; backend)
        arr = collect(0x00:0xff)
        @test write(gzfile, @view arr[1:128]) == 128
        @test write(gzfile, @view arr[129:256]) == 128
        close(gzfile)
        gzfile = gzopen(test_compressed, "r"; backend)
        @test read(gzfile) == arr
        close(gzfile)
    end

    @testset "Strategy read/write" begin
        data = open(x->read(x, String), test_infile);

        # rewrite the test file
        modes = "fhR "
        if GZip.ZLIB_VERSION >= (1,2,5,2)
            modes = "fhRFT "
        end
        for ch in modes
            if ch == ' '
                ch = ""
            end
            for level = 0:9
                gzfile = gzopen(test_compressed, "wb$level$ch"; backend)
                @test write(gzfile, data) == sizeof(data)
                @test close(gzfile) == Z_OK

                file_size = filesize(test_compressed)

                if ch == 'T'
                    @test(file_size == sizeof(data))
                elseif level == 0
                    @test(file_size > sizeof(data))
                else
                    @test(file_size < sizeof(data))
                end

                # readline test
                gzf = gzopen(test_compressed; backend)
                s = IOBuffer()
                while !eof(gzf)
                    write(s, readline(gzf; keep=true))
                end
                data2 = String(take!(s));

                # readuntil test
                seek(gzf, 0)
                while !eof(gzf)
                    write(s, readuntil(gzf, 'a'; keep=true))
                end
                data3 = String(take!(s));
                close(gzf)

                @test(data == data2)
                @test(data == data3)

            end
        end

        # Empty file
        gzfile = gzopen(test_compressed, "wb"; backend)
        @test write(gzfile, "") == 0
        @test close(gzfile) == Z_OK
        gzfile = gzopen(test_compressed, "r"; backend)
        @test eof(gzfile) == true
        @test close(gzfile) == Z_OK
    end

    @testset "Array/matrix read/write" begin
        BUFSIZE = 65536
        for level = 0:3:6
            for T in [Int8,UInt8,Int16,UInt16,Int32,UInt32,Int64,UInt64,Int128,UInt128,
                      Float32,Float64,ComplexF32,ComplexF64]

                minval = 34567
                try
                    minval = min(typemax(T), 34567)
                catch
                    # do nothing
                end

                # Ordered array
                b = zeros(T, BUFSIZE)
                if !isa(T, Complex)
                    for i = 1:length(b)
                        b[i] = (i-1)%minval;
                    end
                else
                    for i = 1:length(b)
                        b[i] = (i-1)%minval - (minval-(i-1))%minval * im
                    end
                end

                # Random array
                if isa(T, AbstractFloat)
                    r = (T)[rand(BUFSIZE)...];
                elseif isa(T, ComplexF32)
                    r = Int32[rand(BUFSIZE)...] + Int32[rand(BUFSIZE)...] * im
                elseif isa(T, ComplexF64)
                    r = Int64[rand(BUFSIZE)...] + Int64[rand(BUFSIZE)...] * im
                else
                    r = b[rand(1:BUFSIZE, BUFSIZE)];
                end

                # Array file
                b_array_fn = joinpath(tmp, "b_array.raw.gz")
                r_array_fn = joinpath(tmp, "r_array.raw.gz")

                gzaf_b = gzopen(b_array_fn, "w$level"; backend)
                write(gzaf_b, b)
                close(gzaf_b)

                gzaf_r = gzopen(r_array_fn, "w$level"; backend)
                write(gzaf_r, r)
                close(gzaf_r)

                b2 = zeros(T, BUFSIZE)
                r2 = zeros(T, BUFSIZE)

                b2_infile = gzopen(b_array_fn; backend)
                read(b2_infile, b2);
                close(b2_infile)

                r2_infile = gzopen(r_array_fn; backend)
                read(r2_infile, r2);
                close(r2_infile)

                @test b == b2
                @test r == r2
            end
        end
    end

    # --- Tests inspired by zlib example.c and CPython test_gzip.py ---

    @testset "Low-level gzputc/gzgetc/gzungetc/gzgets sequence" begin
        # Mirrors zlib's test/example.c test_gzio
        fn = joinpath(tmp, "lowlevel.gz")
        gzfile = gzopen(fn, "wb"; backend)
        gzputc(gzfile, UInt8('h'))
        @test gzwrite(gzfile, pointer("ello"), 4) == 4
        @test write(gzfile, ", world!")  == 8
        @test close(gzfile) == Z_OK

        # Read back and verify
        gzfile = gzopen(fn, "rb"; backend)
        @test read(gzfile, UInt8) == UInt8('h')

        # Read remaining
        buf = read(gzfile, String)
        @test buf == "ello, world!"
        close(gzfile)

        # Seek backward during read (SEEK_CUR via seek to absolute position)
        gzfile = gzopen(fn, "rb"; backend)
        full = read(gzfile, String)
        @test full == "hello, world!"
        seek(gzfile, 8)
        @test position(gzfile) == 8
        rest = read(gzfile, String)
        @test rest == "orld!"

        # gzungetc: push back a byte and read it again
        seek(gzfile, 5)
        c = read(gzfile, UInt8)
        @test c == UInt8(',')
        gzungetc(c, gzfile)
        c2 = read(gzfile, UInt8)
        @test c2 == UInt8(',')
        close(gzfile)
    end

    @testset "Forward seek on write produces null bytes" begin
        fn = joinpath(tmp, "seekwrite.gz")
        gzfile = gzopen(fn, "wb"; backend)
        write(gzfile, "AB")
        skip(gzfile, 3)  # skip 3 bytes (padded with nulls)
        write(gzfile, "CD")
        close(gzfile)

        gzfile = gzopen(fn, "rb"; backend)
        data = read(gzfile)
        close(gzfile)
        @test data == UInt8['A', 'B', 0, 0, 0, 'C', 'D']
    end

    @testset "Position mid-stream" begin
        fn = joinpath(tmp, "position.gz")
        gzfile = gzopen(fn, "wb"; backend)
        @test position(gzfile) == 0
        write(gzfile, "hello")
        @test position(gzfile) == 5
        write(gzfile, " world")
        @test position(gzfile) == 11
        close(gzfile)

        gzfile = gzopen(fn, "rb"; backend)
        @test position(gzfile) == 0
        read(gzfile, 5)
        @test position(gzfile) == 5
        read(gzfile, String)
        @test position(gzfile) == 11
        close(gzfile)
    end

    @testset "IO on closed stream" begin
        fn = joinpath(tmp, "closed.gz")
        gzopen(fn, "w"; backend) do io
            write(io, "data")
        end

        gzfile = gzopen(fn, "r"; backend)
        close(gzfile)

        # All operations on closed stream should throw
        @test_throws EOFError read(gzfile, UInt8)
        @test_throws EOFError read(gzfile, String)
        @test_throws EOFError gzgetc(gzfile)
    end

    @testset "Zero-length write" begin
        fn = joinpath(tmp, "zerolen.gz")
        gzopen(fn, "w"; backend) do io
            @test write(io, UInt8[]) == 0
            write(io, "hello")
            @test write(io, UInt8[]) == 0
        end
        @test gzopen(x->read(x, String), fn; backend) == "hello"
    end

    @testset "Concatenated/multi-member gzip (append)" begin
        fn = joinpath(tmp, "multi.gz")
        gzopen(fn, "wb"; backend) do io
            write(io, "first")
        end
        gzopen(fn, "ab"; backend) do io
            write(io, "second")
        end
        data = gzopen(x->read(x, String), fn; backend)
        @test data == "firstsecond"
    end

    @testset "Corrupt CRC trailer" begin
        fn = joinpath(tmp, "badcrc.gz")
        gzopen(fn, "wb"; backend) do io
            write(io, "hello world " ^ 100)
        end

        # Corrupt the last 8 bytes (CRC32 + ISIZE trailer)
        raw = read(fn)
        raw[end-7:end] .= 0xff
        write(fn, raw)

        # CRC error is detected on close; gzopen do-block calls close which
        # should propagate the error
        @test_throws Union{GZError, ZError} gzopen(fn; backend) do io
            read(io, String)
        end
    end

    @testset "Truncated file" begin
        fn = joinpath(tmp, "trunc.gz")
        gzopen(fn, "wb"; backend) do io
            write(io, "hello world " ^ 100)
        end

        raw = read(fn)

        # Truncated mid-compressed-body (keep first 20 bytes)
        fn_trunc = joinpath(tmp, "trunc_body.gz")
        write(fn_trunc, raw[1:min(20, length(raw))])
        @test_throws Union{GZError, ZError, EOFError, ArgumentError} gzopen(fn_trunc; backend) do io
            read(io, String)
        end

        # Truncated — missing trailer (remove last 8 bytes)
        if length(raw) > 8
            fn_notrailer = joinpath(tmp, "trunc_trailer.gz")
            write(fn_notrailer, raw[1:end-8])
            @test_throws Union{GZError, ZError, EOFError} gzopen(fn_notrailer; backend) do io
                read(io, String)
            end
        end
    end

    finally
        rm(tmp, recursive=true)
    end
end

@testset "zlib backend" begin
    run_backend_tests(; backend=GZip.ZLIB)
end

@testset "zlib-ng backend" begin
    run_backend_tests(; backend=GZip.ZLIBNG)
end

@testset "Cross-backend compatibility" begin
    tmp = mktempdir()
    fn = joinpath(tmp, "cross.gz")
    try
        data = "cross-backend test data: αβγ 🎉"

        # Write with zlib-ng, read with zlib
        gzopen(fn, "w"; backend=GZip.ZLIBNG) do io
            write(io, data)
        end
        @test gzopen(x->read(x, String), fn; backend=GZip.ZLIB) == data

        # Write with zlib, read with zlib-ng
        gzopen(fn, "w"; backend=GZip.ZLIB) do io
            write(io, data)
        end
        @test gzopen(x->read(x, String), fn; backend=GZip.ZLIBNG) == data
    finally
        rm(tmp, recursive=true)
    end
end

using Aqua
Aqua.test_all(GZip)
