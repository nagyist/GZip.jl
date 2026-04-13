# GZip.jl Benchmarks

Compares performance of the **zlib** and **zlib-ng** backends across compression,
decompression, and roundtrip operations.

## Quick start

```bash
# Fast run with synthetic data (~1 min)
julia --project=. test/benchmarks.jl --quick

# Individual corpus
julia --project=. test/benchmarks.jl --silesia   # ~5 min
julia --project=. test/benchmarks.jl --enwik9     # ~5 min

# Full run with all corpora (~10 min)
julia --project=. test/benchmarks.jl

# Include 4GB dataset (enwik9 x4, needs ~16GB RAM)
julia --project=. test/benchmarks.jl --4gb
```

## Datasets

Downloaded automatically on first run and cached in `test/data/` (gitignored).

| Dataset | Size | Description |
|---------|------|-------------|
| Silesia corpus | ~200MB | Standard compression benchmark: text, XML, binaries, source code |
| enwik9 | 1GB | Wikipedia XML extract (Hutter Prize) |
| enwik9 x4 | 4GB | enwik9 repeated 4x (opt-in via `--4gb`) |
| Synthetic random | 10MB | Incompressible random bytes (`--quick` mode only) |

Sources:
- Silesia: https://sun.aei.polsl.pl/~sdeor/index.php?page=silesia
- enwik9: https://mattmahoney.net/dc/textdata.html

## What is measured

- **write** — compress data to a gzip file (levels 1, 9)
- **read** — decompress a gzip file into a pre-allocated buffer via `read!` (both backends read the same zlib-compressed file for fairness)
- **roundtrip** — write then read (levels 1, 9)

Each benchmark reports median, mean, min, max times, and throughput in MB/s
(based on uncompressed data size).

## Sample results

zlib 1.3.1 vs zlib-ng 2.3.3, Julia 1.12.5, Linux x86_64 (AMD EPYC 7513).

### enwik9 — 1GB Wikipedia XML (compression ratio 3.09x)

| Benchmark | zlib | zlib-ng | Speedup |
|---|---|---|---|
| write (level=1) | 92 MB/s | 231 MB/s | **2.52x** |
| write (level=9) | 21 MB/s | 33 MB/s | **1.56x** |
| read | 296 MB/s | 656 MB/s | **2.22x** |
| roundtrip (level=1) | 67 MB/s | 144 MB/s | **2.16x** |
| roundtrip (level=9) | 19 MB/s | 31 MB/s | **1.61x** |

### Silesia corpus — 55MB mixed data

| Benchmark | zlib | zlib-ng | Speedup |
|---|---|---|---|
| write (level=1) | 46 MB/s | 97 MB/s | **2.13x** |
| write (level=9) | 44 MB/s | 47 MB/s | **1.08x** |
| read | 1,041 MB/s | 1,575 MB/s | **1.51x** |
| roundtrip (level=1) | 42 MB/s | 75 MB/s | **1.76x** |
| roundtrip (level=9) | 42 MB/s | 45 MB/s | **1.08x** |

### Key takeaways

- **Compression**: zlib-ng is up to 2.5x faster at level 1, 1.1-1.6x at level 9.
- **Decompression**: zlib-ng is 1.5-2.2x faster depending on data compressibility.
- **Roundtrip**: zlib-ng wins across all levels (up to 2.2x at level 1).
