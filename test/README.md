# GZip.jl Benchmarks

Compares performance of the **zlib** and **zlib-ng** backends across compression,
decompression, and roundtrip operations.

## Quick start

```bash
# Fast run with synthetic data (~1 min)
julia --project=. test/benchmarks.jl --quick

# Full run with real corpora (~30-50 min)
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
- **read** — decompress a gzip file (both backends read the same zlib-compressed file for fairness)
- **roundtrip** — write then read (levels 1, 6, 9)

Each benchmark reports median, mean, min, max times, and throughput in MB/s
(based on uncompressed data size).

## Sample results

zlib 1.3.1 vs zlib-ng 2.3.2, Julia 1.12.5, Linux x86_64 (AMD EPYC 7513).

### enwik9 — 1GB Wikipedia XML (compression ratio 3.09x)

| Benchmark | zlib | zlib-ng | Speedup |
|---|---|---|---|
| write (level=1) | 93 MB/s | 229 MB/s | **2.46x** |
| write (level=6) | 27 MB/s | 69 MB/s | **2.54x** |
| write (level=9) | 21 MB/s | 32 MB/s | **1.50x** |
| read | 225 MB/s | 366 MB/s | **1.62x** |
| roundtrip (level=1) | 66 MB/s | 136 MB/s | **2.07x** |
| roundtrip (level=6) | 24 MB/s | 57 MB/s | **2.37x** |
| roundtrip (level=9) | 20 MB/s | 29 MB/s | **1.51x** |

### Silesia corpus — 55MB mixed data

| Benchmark | zlib | zlib-ng | Speedup |
|---|---|---|---|
| write (level=1) | 46 MB/s | 98 MB/s | **2.14x** |
| write (level=6) | 45 MB/s | 42 MB/s | 0.94x |
| write (level=9) | 44 MB/s | 46 MB/s | 1.05x |
| read | 454 MB/s | 512 MB/s | **1.13x** |
| roundtrip (level=1) | 42 MB/s | 69 MB/s | **1.65x** |

### Key takeaways

- **Compression**: zlib-ng is 2-2.5x faster on compressible text data at levels 1 and 6.
- **Decompression**: zlib-ng is 1.6x faster on compressible data (enwik9).
- **Roundtrip**: zlib-ng wins across all levels on enwik9 (up to 2.37x at level 6).
