/// Central tuning constants for final_rom.
///
/// Home for performance-related buffer/chunk sizes that are **not** exposed
/// through the settings screen — values you'd otherwise sprinkle through the
/// codebase as `1024 * 1024` magic numbers. Keeping them here means each is
/// documented once (with its benchmark rationale) and changed in one place.
///
/// User-configurable knobs (NSZ compression level, thread count, the
/// per-archive chunk size) intentionally do **not** live here — they come from
/// the settings/benchmark UI and are passed in as parameters.
///
/// Benchmarks behind these numbers: `tool/bench_pfs0_assembly.dart` (chunk-size
/// sweep) and `tool/bench_3ds_split.dart`.
library;

/// One mebibyte, the unit the sizes below are expressed in.
const int _mib = 1024 * 1024;

/// Copy/CRC buffer for the ROM patchers (IPS/PPF/APS/UPS/BPS and `crc32OfFile`).
///
/// 1 MiB. Benchmarking showed 64 KB reads run at ~1.2 GB/s vs ~3 GB/s for
/// chunks ≥ 256 KB — small chunks are syscall-bound. 1 MiB sits in the fast,
/// flat region while staying modest for mobile RAM.
const int patchCopyBufferSize = 1 * _mib;

/// Read buffer for the Dart file-hashing pass (CRC32 on desktop; all four on
/// mobile). 4 MiB amortises per-chunk overhead; the path is CPU-bound, so
/// larger buffers do not help.
const int hashReadBufferSize = 4 * _mib;

/// Per-chunk IO size for the NCZ (NSZ/XCZ) codec's streaming compress/decompress
/// loop. Large enough for zstd workers to distribute blocks, small enough to
/// avoid GC spikes on multi-GB archives.
const int nczIoChunkSize = 2 * _mib;

/// Default chunk size when copying a single PFS0 member to a sink
/// ([Pfs0Reader.copyEntryTo]).
const int pfs0EntryCopyChunkSize = 8 * _mib;

/// Default chunk size when assembling a PFS0 container ([Pfs0Builder.writeTo]).
///
/// 16 MiB balances sequential throughput against Dart GC pressure from large
/// `Uint8List` allocations. Note: reusing one buffer with `readInto` was
/// benchmarked and is *slower* than allocating per chunk with `read()`, so the
/// assembly loop deliberately allocates per chunk.
const int pfs0AssemblyChunkSize = 16 * _mib;

/// Chunk size for the XCZ archive's verbatim header/region copies and temp-file
/// passes.
const int xczCopyChunkSize = 8 * _mib;
