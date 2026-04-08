using GZip
using Test

tmp = mktempdir()

test_infile = @__FILE__
test_compressed = joinpath(tmp, "runtests.jl.gz")
test_empty = joinpath(tmp, "empty.jl.gz")

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

try

@testset "Compress and decompress" begin
    data = open(x->read(x, String), test_infile);

    first_char = data[1]

    gzfile = gzopen(test_compressed, "wb")
    @test write(gzfile, data) == sizeof(data)
    @test close(gzfile) == Z_OK
    @test close(gzfile) != Z_OK

    @test_throws EOFError write(gzfile, data)

    if test_gunzip
        data2 = read(`$gunzip -c $test_compressed`, String)
        @test data == data2
    end

    data3 = gzopen(x->read(x, String), test_compressed)
    @test data == data3

    # Test gzfdio
    @test_throws "No such file or directory" gzopen("wrong_file.gz", "r")
    @test_throws "Bad file descriptor" gzdopen("wrong_fd.gz", -1, "r", 1024)

    raw_file = open(test_compressed, "r")
    gzfile = gzdopen(fd(raw_file), "r")
    data4 = read(gzfile, String)
    close(gzfile)
    close(raw_file)
    @test data == data4

    # Test peek
    gzfile = gzopen(test_compressed, "r")
    @test peek(gzfile) == UInt(first_char)
    read(gzfile, String)
    @test peek(gzfile) == -1
    close(gzfile)

    # Corrupt file
    raw_file = open(test_compressed, "r+")
    seek(raw_file, 3) # leave the gzip magic 2-byte header
    write(raw_file, zeros(UInt8, 10))
    close(raw_file)

    try
        gzopen(x->read(x, String), test_compressed)
        throw(ErrorException("Expecting ArgumentError or similar"))
    catch ex
        @test typeof(ex) <: Union{ArgumentError,ZError,GZError} ||
              contains(ex.msg, "too many arguments")
    end
end

@testset "readbytes!" begin
    gzopen(test_compressed, "w") do io
        write(io, "hello world")
    end
    gzopen(test_compressed) do io
        buf = Vector{UInt8}(undef, 5)
        @test readbytes!(io, buf) == 5
        @test buf == b"hello"
        buf2 = Vector{UInt8}(undef, 100)
        @test readbytes!(io, buf2) == 6
        @test buf2[1:6] == b" world"
    end
end

@testset "readline keep keyword" begin
    gzopen(test_compressed, "w") do io
        write(io, "line1\nline2\nline3")
    end

    # Default (keep=false) should strip newlines
    gzopen(test_compressed) do io
        @test readline(io) == "line1"
        @test readline(io) == "line2"
        @test readline(io) == "line3"
    end

    # keep=true should preserve newlines
    gzopen(test_compressed) do io
        @test readline(io; keep=true) == "line1\n"
        @test readline(io; keep=true) == "line2\n"
        @test readline(io; keep=true) == "line3"
    end
end

@testset "Writing" begin
    data = open(x->read(x, String), test_infile);

    gzfile = gzopen(test_compressed, "wb")
    write(gzfile, data) == sizeof(data)
    @test flush(gzfile) == Z_OK

    NEW = GZip.GZLIB_VERSION > "1.2.3.9"
    pos = position(gzfile)
    NEW && (pos2 = position(gzfile,true))
    @test_throws ErrorException seek(gzfile, 100)   # can't seek backwards on write
    @test position(gzfile) == pos
    NEW && (@test position(gzfile,true) == pos2)
    @test skip(gzfile, 100)
    @test position(gzfile) == pos + 100
    NEW && (@test position(gzfile,true) == pos2)

    @test_throws MethodError truncate(gzfile, 100)
    @test_throws MethodError seekend(gzfile)

    @test close(gzfile) == Z_OK

    gzopen(test_empty, "w") do io
        a = UInt8[]
        @test gzwrite(io, pointer(a), length(a)*sizeof(eltype(a))) == Int32(0)
    end

    # write(::GZipStream, ::UInt8) should return 1 (byte count, not value)
    gzopen(test_compressed, "w") do io
        @test write(io, 0x0a) == 1
        @test write(io, 0xff) == 1
    end

    # Test writing SubArrays (views)
    gzfile = gzopen(test_compressed, "wb")
    arr = collect(0x00:0xff)
    @test write(gzfile, @view arr[1:128]) == 128
    @test write(gzfile, @view arr[129:256]) == 128
    close(gzfile)
    gzfile = gzopen(test_compressed, "r")
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
            gzfile = gzopen(test_compressed, "wb$level$ch")
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
            gzf = gzopen(test_compressed)
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
    gzfile = gzopen(test_compressed, "wb")
    @test write(gzfile, "") == 0
    @test close(gzfile) == Z_OK
    gzfile = gzopen(test_compressed, "r")
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

            gzaf_b = gzopen(b_array_fn, "w$level")
            write(gzaf_b, b)
            close(gzaf_b)

            gzaf_r = gzopen(r_array_fn, "w$level")
            write(gzaf_r, r)
            close(gzaf_r)

            b2 = zeros(T, BUFSIZE)
            r2 = zeros(T, BUFSIZE)

            b2_infile = gzopen(b_array_fn)
            read(b2_infile, b2);
            close(b2_infile)

            r2_infile = gzopen(r_array_fn)
            read(r2_infile, r2);
            close(r2_infile)

            @test b == b2
            @test r == r2
        end
    end
end

finally
    rm(tmp, recursive=true)
end

using Aqua
Aqua.test_all(GZip)
