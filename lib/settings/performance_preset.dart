import 'dart:io';

/// User-selectable performance tier. The first three are device-capability
/// classes; [custom] hands control back to the individual settings sliders.
///
/// A tier is a *combined matrix*: it picks a CPU/RAM budget for the device, and
/// the resolver ([resolvePreset]) then adapts that budget to the actual input —
/// e.g. spending it on parallel NCA isolates only when an archive really has
/// several large NCAs (a merged NSP), versus a single dominant NCA (a plain base
/// game or update) where extra workers cannot help.
enum PerformancePreset { weak, mid, high, custom }

extension PerformancePresetLabel on PerformancePreset {
  String get label => switch (this) {
        PerformancePreset.weak => 'Weak device',
        PerformancePreset.mid => 'Balanced',
        PerformancePreset.high => 'High performance',
        PerformancePreset.custom => 'Custom',
      };

  String get description => switch (this) {
        PerformancePreset.weak =>
          'Low RAM/CPU use for entry-level phones; caps parallelism.',
        PerformancePreset.mid =>
          'Sensible balance of speed and resource use for most devices.',
        PerformancePreset.high =>
          'Uses all CPU cores for fastest conversions on desktops/strong phones.',
        PerformancePreset.custom => 'Use the individual values set below.',
      };
}

/// Describes the input being processed so the resolver can adapt a tier's budget
/// to the archive's actual NCA layout. Built cheaply from a PFS0 header — no
/// full file read.
class InputProfile {
  final int totalBytes;

  /// Number of NCAs large enough to be worth compressing (> 0x4000).
  final int compressibleNcaCount;

  /// Largest single NCA as a fraction of all NCA bytes (1.0 == one NCA holds
  /// everything). Above [_dominantThreshold] the archive is "dominant-NCA":
  /// parallelism across NCAs cannot help because one NCA is the whole job.
  final double largestNcaFraction;

  const InputProfile({
    required this.totalBytes,
    required this.compressibleNcaCount,
    required this.largestNcaFraction,
  });

  static const double _dominantThreshold = 0.6;

  /// True when one NCA dominates, so per-NCA parallelism yields no speed-up
  /// (the common case: plain base games and updates are a single 100% NCA).
  bool get isDominantNca =>
      compressibleNcaCount <= 1 || largestNcaFraction >= _dominantThreshold;
}

/// The concrete parameters a tier (plus input) resolves to. Mirrors the
/// individual fields on `AppSettings` so call sites can use either source.
class ResolvedTuning {
  final int nszThreadCount;
  final int nszChunkSizeMB;
  final bool nszParallel;

  /// Max NCA-compression isolates allowed to run at once. This is the key knob
  /// that keeps a many-NCA (merged) archive from spawning one isolate per NCA
  /// and overwhelming a weak device's RAM/CPU.
  final int nszMaxConcurrentNcas;

  final int compressionLevel;
  final String chdCodecs;
  final int chdNumProcessors;
  final int chdHunkBytes;

  /// 3DS batch concurrency (number of files decrypted/encrypted at once).
  final int parallelism;

  const ResolvedTuning({
    required this.nszThreadCount,
    required this.nszChunkSizeMB,
    required this.nszParallel,
    required this.nszMaxConcurrentNcas,
    required this.compressionLevel,
    required this.chdCodecs,
    required this.chdNumProcessors,
    required this.chdHunkBytes,
    required this.parallelism,
  });
}

/// Per-tier device budget, independent of the specific input. The CHD and 3DS
/// numbers come from benchmark sweeps; the NSZ `nszThreadCount` was reset when
/// AES-CTR moved to native Mbed TLS crypto — the old values encoded the
/// pure-Dart AES bottleneck (see `nsz-investigation.md`) and warrant a fresh
/// sweep on native-AES hardware.
///
/// Workloads scale very differently, so each gets its own cap rather than one
/// shared budget:
///  * CHD (chdman LZMA) is heavily multi-threaded and scales almost linearly to
///    all cores with no effect on size — High uses every core.
///  * 3DS batch and per-NCA NSZ isolates each do copy + crypto, so they peak at
///    ~4 concurrent and *degrade* beyond it (IO/memory contention) — capped.
class _TierBudget {
  /// chdman `-np`. 0 means "all cores".
  final int Function(int cores) chdNumProcessors;

  /// 3DS batch concurrency. Benchmarks peak at 4 and regress past it.
  final int Function(int cores) threeDsParallelism;

  /// Max concurrent NCA-compression isolates (only relevant to many-NCA / merged
  /// archives). Same copy+crypto shape as 3DS, so capped similarly.
  final int Function(int cores) nszMaxConcurrentNcas;

  final int nszChunkSizeMB;
  final int nszThreadCount;
  final int compressionLevel;
  const _TierBudget({
    required this.chdNumProcessors,
    required this.threeDsParallelism,
    required this.nszMaxConcurrentNcas,
    required this.nszChunkSizeMB,
    required this.nszThreadCount,
    required this.compressionLevel,
  });
}

const _balancedCodecs = 'cdlz,cdzl,cdfl';

final Map<PerformancePreset, _TierBudget> _budgets = {
  // Retuned after AES-CTR moved to native Mbed TLS (see nsz-investigation.md):
  // decryption is no longer the wall, so zstd itself is now the limiting stage
  // and its worker count matters again. nszThreadCount is raised per tier — High
  // delegates to the core-aware Auto default (0 -> cores-2, mobile-capped), Mid
  // runs a fixed 4, Weak a memory-conscious 2 — because even a single dominant
  // NCA (the common case) now benefits from parallel zstd workers rather than
  // stalling on the AES pipeline.
  //
  // compressionLevel 15 stays the default "knee": at 17+ zstd switches to
  // btultra, which now carries a real (zstd-bound) time cost for <1.5% extra
  // size. Weak stays at 12 as a hedge for slower CPUs. Level 18 for High may be
  // worth revisiting once a field NSZ benchmark on native-AES hardware exists.
  PerformancePreset.weak: _TierBudget(
    chdNumProcessors: (cores) => 2,
    threeDsParallelism: (cores) => 2,
    nszMaxConcurrentNcas: (cores) => 2,
    nszChunkSizeMB: 1,
    nszThreadCount: 2,
    compressionLevel: 12,
  ),
  PerformancePreset.mid: _TierBudget(
    chdNumProcessors: (cores) => (cores ~/ 2).clamp(2, 8),
    threeDsParallelism: (cores) => cores.clamp(2, 4),
    nszMaxConcurrentNcas: (cores) => cores.clamp(2, 4),
    nszChunkSizeMB: 2,
    nszThreadCount: 4,
    compressionLevel: 15,
  ),
  PerformancePreset.high: _TierBudget(
    chdNumProcessors: (cores) => 0, // all cores
    threeDsParallelism: (cores) => cores.clamp(2, 4),
    nszMaxConcurrentNcas: (cores) => cores.clamp(2, 6),
    nszChunkSizeMB: 4,
    nszThreadCount: 0, // Auto: cores-2 (ZstdEncoder.defaultWorkerCount), mobile-capped
    compressionLevel: 15,
  ),
};

/// Resolves a tier (and optional input) to concrete parameters.
///
/// For [PerformancePreset.custom], pass [customFallback] (the user's raw
/// settings); it is returned unchanged.
ResolvedTuning resolvePreset({
  required PerformancePreset tier,
  int? cores,
  InputProfile? input,
  ResolvedTuning? customFallback,
}) {
  if (tier == PerformancePreset.custom) {
    if (customFallback == null) {
      throw ArgumentError('custom preset requires customFallback');
    }
    return customFallback;
  }

  final coreCount = cores ?? _cores();
  final budget = _budgets[tier]!;

  // NSZ: a single dominant NCA is AES-pipeline-bound and cannot be sped up by
  // parallel isolates, so the concurrency cap only matters for many-NCA (merged)
  // archives. Keep parallel on (harmless when there is one NCA) but cap the
  // concurrent isolates to the device budget to protect weak devices.
  final manyNca = input != null && !input.isDominantNca;
  final nszMaxConcurrentNcas =
      manyNca ? budget.nszMaxConcurrentNcas(coreCount) : 1;

  return ResolvedTuning(
    nszThreadCount: budget.nszThreadCount,
    nszChunkSizeMB: budget.nszChunkSizeMB,
    nszParallel: true,
    nszMaxConcurrentNcas: nszMaxConcurrentNcas,
    compressionLevel: budget.compressionLevel,
    chdCodecs: _balancedCodecs,
    chdNumProcessors: budget.chdNumProcessors(coreCount),
    chdHunkBytes: 0,
    parallelism: budget.threeDsParallelism(coreCount),
  );
}

int _cores() {
  try {
    return Platform.numberOfProcessors;
  } catch (_) {
    return 1;
  }
}
