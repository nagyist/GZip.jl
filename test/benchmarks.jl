#!/usr/bin/env julia
#
# GZip.jl Benchmark: zlib vs zlib-ng backend comparison
#
# Usage:
#   julia --project=. test/benchmarks.jl            # full suite with real corpora
#   julia --project=. test/benchmarks.jl --quick     # synthetic data only, fewer iterations
#   julia --project=. test/benchmarks.jl --silesia   # Silesia corpus only (~5 min)
#   julia --project=. test/benchmarks.jl --enwik9    # enwik9 only (~5 min)
#   julia --project=. test/benchmarks.jl --4gb       # include 4GB dataset (enwik9 x4)
#
# Downloads enwik9 (~300MB) and Silesia corpus (~68MB) on first run.
# Cached in test/data/ for subsequent runs.

using GZip
using Statistics
using Printf
using Downloads

const QUICK = "--quick" in ARGS
const RUN_4GB = "--4gb" in ARGS
const RUN_SILESIA = "--silesia" in ARGS
const RUN_ENWIK9 = "--enwik9" in ARGS
const RUN_ALL = !QUICK && !RUN_SILESIA && !RUN_ENWIK9 && !RUN_4GB
const DATA_DIR = joinpath(@__DIR__, "data")

# ---------------------------------------------------------------------------
# Dataset management
# ---------------------------------------------------------------------------

function ensure_dir(path)
    isdir(path) || mkpath(path)
end

"""Download a file if not already present. Returns the local path."""
function ensure_download(url::String, dest::String; desc::String="")
    if isfile(dest)
        println("  [cached] $desc -> $dest ($(filesize(dest) ÷ 1_000_000) MB)")
        return dest
    end
    println("  [downloading] $desc")
    println("    $url")
    Downloads.download(url, dest)
    println("    -> $dest ($(filesize(dest) ÷ 1_000_000) MB)")
    dest
end

"""Download and extract enwik9 (1GB uncompressed Wikipedia XML)."""
function ensure_enwik9()
    ensure_dir(DATA_DIR)
    txt = joinpath(DATA_DIR, "enwik9")
    if isfile(txt)
        println("  [cached] enwik9 -> $txt ($(filesize(txt) ÷ 1_000_000) MB)")
        return txt
    end
    zip = joinpath(DATA_DIR, "enwik9.zip")
    ensure_download(
        "https://mattmahoney.net/dc/enwik9.zip", zip;
        desc="enwik9.zip (~300MB)")
    println("  [extracting] enwik9.zip...")
    run(`unzip -o -d $DATA_DIR $zip`)
    @assert isfile(txt) "Expected $txt after extraction"
    println("    -> $txt ($(filesize(txt) ÷ 1_000_000) MB)")
    rm(zip; force=true)
    txt
end

"""Download Silesia corpus files (~200MB uncompressed total)."""
function ensure_silesia()
    ensure_dir(DATA_DIR)
    silesia_dir = joinpath(DATA_DIR, "silesia")
    ensure_dir(silesia_dir)

    # Silesia corpus individual files
    files = [
        "dickens", "mozilla", "mr", "nci",
        "ooffice", "osdb", "reymont", "samba",
        "sao", "webster", "xml", "x-ray",
    ]
    base_url = "https://sun.aei.polsl.pl/~sdeor/corpus"

    all_present = all(isfile(joinpath(silesia_dir, f)) for f in files)
    if all_present
        total = sum(filesize(joinpath(silesia_dir, f)) for f in files)
        println("  [cached] silesia corpus -> $silesia_dir ($(total ÷ 1_000_000) MB)")
        return silesia_dir
    end

    for f in files
        dest = joinpath(silesia_dir, f)
        ensure_download("$base_url/$f", dest; desc="silesia/$f")
    end
    silesia_dir
end

"""Read a file as a byte vector."""
load_file(path::String) = read(path)

"""Concatenate Silesia corpus into a single byte vector."""
function load_silesia(dir::String)
    files = ["dickens", "mozilla", "mr", "nci", "ooffice", "osdb",
             "reymont", "samba", "sao", "webster", "xml", "x-ray"]
    vcat((read(joinpath(dir, f)) for f in files)...)
end

"""Create a 4GB dataset by repeating enwik9 4x."""
function make_4gb(enwik9_path::String)
    data = read(enwik9_path)
    println("  Repeating enwik9 4x to create ~4GB dataset...")
    repeat(data, 4)
end

# ---------------------------------------------------------------------------
# Benchmark infrastructure
# ---------------------------------------------------------------------------

struct BenchResult
    label::String
    backend::String
    median_ms::Float64
    mean_ms::Float64
    min_ms::Float64
    max_ms::Float64
    throughput_MBs::Float64   # based on median, using uncompressed size
end

function bench(f::Function, label::String, backend_name::String, data_size::Int;
               warmup::Int=1, iters::Int=QUICK ? 3 : 1)
    for _ in 1:warmup
        f()
    end
    GC.gc()

    times = Float64[]
    for i in 1:iters
        GC.gc(false)
        t = @elapsed f()
        push!(times, t)
    end

    med = median(times)
    throughput = (data_size / 1e6) / med  # MB/s

    BenchResult(label, backend_name, med * 1e3, mean(times) * 1e3,
                minimum(times) * 1e3, maximum(times) * 1e3, throughput)
end

# ---------------------------------------------------------------------------
# Benchmark definitions
# ---------------------------------------------------------------------------

function bench_write(data::Vector{UInt8}, backend, backend_name::String; level::Int=6)
    tmpfile = tempname() * ".gz"
    mode = "w$level"
    r = bench("write (level=$level)", backend_name, length(data)) do
        GZip.open(tmpfile, mode; backend=backend) do gz
            write(gz, data)
        end
    end
    rm(tmpfile; force=true)
    r
end

function bench_read(data::Vector{UInt8}, backend, backend_name::String;
                    compressed_file::String)
    buf = Vector{UInt8}(undef, length(data))
    r = bench("read", backend_name, length(data)) do
        GZip.open(compressed_file, "r"; backend=backend) do gz
            read!(gz, buf)
        end
    end
    r
end

function bench_roundtrip(data::Vector{UInt8}, backend, backend_name::String; level::Int=6)
    tmpfile = tempname() * ".gz"
    mode = "w$level"
    r = bench("roundtrip (level=$level)", backend_name, length(data)) do
        GZip.open(tmpfile, mode; backend=backend) do gz
            write(gz, data)
        end
        GZip.open(tmpfile, "r"; backend=backend) do gz
            read(gz)
        end
    end
    rm(tmpfile; force=true)
    r
end

# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

function print_table(results::Vector{BenchResult})
    @printf("%-28s  %-8s  %10s  %10s  %10s  %10s  %10s\n",
            "Benchmark", "Backend", "Median", "Mean", "Min", "Max", "Throughput")
    @printf("%-28s  %-8s  %10s  %10s  %10s  %10s  %10s\n",
            "", "", "(ms)", "(ms)", "(ms)", "(ms)", "(MB/s)")
    println("-"^100)
    for r in results
        @printf("%-28s  %-8s  %10.1f  %10.1f  %10.1f  %10.1f  %10.1f\n",
                r.label, r.backend, r.median_ms, r.mean_ms, r.min_ms, r.max_ms, r.throughput_MBs)
    end
end

function print_comparison(results::Vector{BenchResult})
    println()
    println("=== Speedup (zlib-ng vs zlib) ===")
    println()
    labels = unique(r.label for r in results)
    @printf("%-28s  %10s  %10s  %10s\n", "Benchmark", "zlib (ms)", "zlib-ng", "Speedup")
    println("-"^64)
    for label in labels
        zlib_r = findfirst(r -> r.label == label && r.backend == "zlib", results)
        zlibng_r = findfirst(r -> r.label == label && r.backend == "zlib-ng", results)
        if zlib_r !== nothing && zlibng_r !== nothing
            z = results[zlib_r]
            n = results[zlibng_r]
            speedup = z.median_ms / n.median_ms
            @printf("%-28s  %10.1f  %10.1f  %9.2fx\n",
                    label, z.median_ms, n.median_ms, speedup)
        end
    end
end

function size_label(nbytes::Int)
    if nbytes >= 1_000_000_000
        @sprintf("%.1fGB", nbytes / 1e9)
    elseif nbytes >= 1_000_000
        @sprintf("%.0fMB", nbytes / 1e6)
    else
        @sprintf("%.0fKB", nbytes / 1e3)
    end
end

# ---------------------------------------------------------------------------
# Run a benchmark suite on a given dataset
# ---------------------------------------------------------------------------

function run_suite(name::String, data::Vector{UInt8};
                   levels::Vector{Int}=[1, 6, 9])
    backends = [(GZip.ZLIB, "zlib"), (GZip.ZLIBNG, "zlib-ng")]
    sl = size_label(length(data))
    println()
    println("=" ^ 70)
    println("  $name  ($sl)")
    println("=" ^ 70)
    println()

    results = BenchResult[]

    # Write benchmarks
    for level in levels
        for (be, bname) in backends
            print("  benchmarking write (level=$level) [$bname]...")
            r = bench_write(data, be, bname; level=level)
            @printf(" %.1f ms (%.1f MB/s)\n", r.median_ms, r.throughput_MBs)
            push!(results, r)
        end
    end

    # Read benchmark (shared compressed file for fairness)
    read_tmpfile = tempname() * ".gz"
    GZip.open(read_tmpfile, "w6"; backend=GZip.ZLIB) do gz
        write(gz, data)
    end
    compressed_sz = filesize(read_tmpfile)
    println("  compressed test file: $(compressed_sz ÷ 1000) KB ",
            "(ratio: $(@sprintf("%.2f", length(data) / compressed_sz))x)")
    for (be, bname) in backends
        print("  benchmarking read [$bname]...")
        r = bench_read(data, be, bname; compressed_file=read_tmpfile)
        @printf(" %.1f ms (%.1f MB/s)\n", r.median_ms, r.throughput_MBs)
        push!(results, r)
    end
    rm(read_tmpfile; force=true)

    # Roundtrip benchmarks
    for level in levels
        for (be, bname) in backends
            print("  benchmarking roundtrip (level=$level) [$bname]...")
            r = bench_roundtrip(data, be, bname; level=level)
            @printf(" %.1f ms (%.1f MB/s)\n", r.median_ms, r.throughput_MBs)
            push!(results, r)
        end
    end

    println()
    print_table(results)
    print_comparison(results)
    println()

    results
end

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

function main()
    println("GZip.jl Benchmark: zlib vs zlib-ng")
    println("===================================")
    println()
    println("zlib version:    ", GZip.Zlib_h.zlibVersion() |> unsafe_string)
    println("zlib-ng version: ", GZip.ZlibNG_h.zlibng_version() |> unsafe_string)
    println("Julia version:   ", VERSION)
    println("Quick mode:      ", QUICK)

    all_results = BenchResult[]

    if QUICK
        # Quick mode: synthetic data only
        println()
        println("--- Synthetic data benchmarks ---")
        data = rand(UInt8, 10_000_000)  # 10MB random
        append!(all_results, run_suite("Synthetic random (10MB)", data; levels=[1, 6]))
    else
        println()
        println("--- Preparing datasets ---")
        println()

        if RUN_ALL || RUN_SILESIA
            print("Silesia corpus:\n")
            silesia_dir = ensure_silesia()
            silesia_data = load_silesia(silesia_dir)
            println()
            append!(all_results, run_suite("Silesia corpus", silesia_data; levels=[1, 9]))
            silesia_data = nothing
            GC.gc()
        end

        if RUN_ALL || RUN_ENWIK9
            print("enwik9:\n")
            enwik9_path = ensure_enwik9()
            println()
            enwik9_data = load_file(enwik9_path)
            append!(all_results, run_suite("enwik9 (Wikipedia XML)", enwik9_data; levels=[1, 9]))
            enwik9_data = nothing
            GC.gc()
        end

        if RUN_4GB
            print("enwik9:\n")
            enwik9_path = ensure_enwik9()
            println()
            data_4gb = make_4gb(enwik9_path)
            GC.gc()
            append!(all_results, run_suite("enwik9 x4 (4GB)", data_4gb; levels=[1, 6]))
            data_4gb = nothing
            GC.gc()
        end
    end

    println()
    println("=" ^ 70)
    println("  OVERALL SUMMARY")
    println("=" ^ 70)
    print_comparison(all_results)
    println()
end

main()
