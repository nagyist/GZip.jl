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

- **write** — compress data to a gzip file (levels 1, 6, 9)
- **read** — decompress a gzip file into a pre-allocated buffer via `read!` (both backends read the same zlib-compressed file for fairness)
- **roundtrip** — write then read (levels 1, 6, 9)

Each benchmark reports median, mean, min, max times, and throughput in MB/s
(based on uncompressed data size).

## Sample results

zlib 1.3.1 vs zlib-ng 2.3.2, Julia 1.12.6, macOS arm64 (Apple M2 Max).

### Synthetic random — 10MB incompressible data (ratio 1.00x)

| Benchmark | zlib | zlib-ng | Speedup |
|---|---|---|---|
| write (level=1) | 41 MB/s | 84 MB/s | **2.05x** |
| write (level=6) | 37 MB/s | 45 MB/s | **1.23x** |
| read | 2,279 MB/s | 3,759 MB/s | **1.65x** |
| roundtrip (level=1) | 40 MB/s | 62 MB/s | **1.53x** |
| roundtrip (level=6) | 36 MB/s | 44 MB/s | **1.22x** |

### Silesia corpus — 55MB mixed data (ratio 1.00x)

| Benchmark | zlib | zlib-ng | Speedup |
|---|---|---|---|
| write (level=1) | 41 MB/s | 84 MB/s | **2.04x** |
| write (level=6) | 37 MB/s | 45 MB/s | **1.23x** |
| write (level=9) | 36 MB/s | 44 MB/s | **1.23x** |
| read | 849 MB/s | 959 MB/s | **1.13x** |
| roundtrip (level=1) | 40 MB/s | 62 MB/s | **1.57x** |
| roundtrip (level=6) | 35 MB/s | 43 MB/s | **1.24x** |
| roundtrip (level=9) | 35 MB/s | 42 MB/s | **1.21x** |

### Key takeaways

- **Compression**: zlib-ng is ~2x faster at level 1, ~1.2x at levels 6 and 9.
- **Decompression**: zlib-ng is 1.1-1.7x faster depending on data compressibility.
- **Roundtrip**: zlib-ng wins across all levels (up to 1.57x at level 1).
