import 'package:final_rom/settings/performance_preset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InputProfile.isDominantNca', () {
    test('single NCA is dominant', () {
      const profile = InputProfile(
          totalBytes: 1000, compressibleNcaCount: 1, largestNcaFraction: 1.0);
      expect(profile.isDominantNca, isTrue);
    });

    test('one NCA holding most bytes is dominant', () {
      const profile = InputProfile(
          totalBytes: 1000, compressibleNcaCount: 4, largestNcaFraction: 0.99);
      expect(profile.isDominantNca, isTrue);
    });

    test('several comparable NCAs are not dominant', () {
      const profile = InputProfile(
          totalBytes: 1000, compressibleNcaCount: 4, largestNcaFraction: 0.3);
      expect(profile.isDominantNca, isFalse);
    });
  });

  group('resolvePreset NSZ concurrency', () {
    test('dominant-NCA input caps concurrent NCAs to 1 on every tier', () {
      const dominant = InputProfile(
          totalBytes: 1000, compressibleNcaCount: 1, largestNcaFraction: 1.0);
      for (final tier in [
        PerformancePreset.weak,
        PerformancePreset.mid,
        PerformancePreset.high,
      ]) {
        final tuning = resolvePreset(tier: tier, cores: 12, input: dominant);
        expect(tuning.nszMaxConcurrentNcas, 1,
            reason: '$tier should not over-spawn on a single-NCA archive');
      }
    });

    test('many-NCA input scales concurrency with the tier budget', () {
      const many = InputProfile(
          totalBytes: 1000, compressibleNcaCount: 8, largestNcaFraction: 0.2);
      final weak = resolvePreset(
          tier: PerformancePreset.weak, cores: 12, input: many);
      final high = resolvePreset(
          tier: PerformancePreset.high, cores: 12, input: many);
      expect(weak.nszMaxConcurrentNcas, lessThan(high.nszMaxConcurrentNcas));
      expect(weak.nszMaxConcurrentNcas, 2);
    });
  });

  group('resolvePreset CPU budgets', () {
    test('weak tier is capped regardless of core count', () {
      final tuning =
          resolvePreset(tier: PerformancePreset.weak, cores: 32);
      expect(tuning.parallelism, 2);
      expect(tuning.chdNumProcessors, 2);
    });

    test('high tier uses all CHD cores (np=0) but caps 3DS parallelism', () {
      final tuning =
          resolvePreset(tier: PerformancePreset.high, cores: 12);
      expect(tuning.chdNumProcessors, 0);
      // 3DS copy+decrypt peaks at 4 concurrent and regresses past it.
      expect(tuning.parallelism, 4); // clamp(12, 2, 4)
    });

    test('mid tier clamps to a moderate budget', () {
      final tuning = resolvePreset(tier: PerformancePreset.mid, cores: 12);
      expect(tuning.parallelism, 4); // clamp(12, 2, 4)
    });
  });

  group('resolvePreset custom', () {
    test('custom returns the supplied fallback unchanged', () {
      const fallback = ResolvedTuning(
        nszThreadCount: 7,
        nszChunkSizeMB: 9,
        nszParallel: false,
        nszMaxConcurrentNcas: 3,
        compressionLevel: 21,
        chdCodecs: 'cdfl',
        chdNumProcessors: 5,
        chdHunkBytes: 123,
        parallelism: 6,
      );
      final tuning = resolvePreset(
          tier: PerformancePreset.custom,
          cores: 12,
          customFallback: fallback);
      expect(identical(tuning, fallback), isTrue);
    });
  });
}
