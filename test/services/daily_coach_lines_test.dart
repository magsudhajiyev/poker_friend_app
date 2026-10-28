import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/daily_coach_lines_service.dart';

/// The per-user-per-day variant pick (update 5) is driven by two pure helpers
/// on DailyCoachLinesService — tested here without touching Firestore.
void main() {
  group('stableHash', () {
    test('is deterministic for the same input', () {
      expect(
        DailyCoachLinesService.stableHash('abc'),
        DailyCoachLinesService.stableHash('abc'),
      );
    });

    test('is non-negative and differs across inputs', () {
      final a = DailyCoachLinesService.stableHash('uid1|2026-10-28|spot|raise');
      final b = DailyCoachLinesService.stableHash('uid2|2026-10-28|spot|raise');
      expect(a, greaterThanOrEqualTo(0));
      expect(b, greaterThanOrEqualTo(0));
      expect(a, isNot(b));
    });

    test('known FNV-1a vectors (locks the algorithm so it never drifts)', () {
      // FNV-1a 32-bit: hash of "" is the offset basis 2166136261.
      expect(DailyCoachLinesService.stableHash(''), 2166136261);
      // "a" → 0xe40c292c = 3826002220.
      expect(DailyCoachLinesService.stableHash('a'), 3826002220);
    });
  });

  group('pickVariantIndex', () {
    test('count <= 1 always returns 0', () {
      expect(DailyCoachLinesService.pickVariantIndex('anything', 1), 0);
      expect(DailyCoachLinesService.pickVariantIndex('anything', 0), 0);
    });

    test('(a) same seed → same index every call', () {
      const seed = 'uidX|2026-10-28|bb-hj-8h5h3c-33|call';
      final first = DailyCoachLinesService.pickVariantIndex(seed, 2);
      for (var i = 0; i < 20; i++) {
        expect(DailyCoachLinesService.pickVariantIndex(seed, 2), first);
      }
      expect(first, inInclusiveRange(0, 1));
    });

    test('(b) different users split across both variants', () {
      const day = '2026-10-28', spot = 'bb-hj-8h5h3c-33', action = 'raise';
      final indices = <int>{};
      for (var u = 0; u < 10; u++) {
        indices.add(DailyCoachLinesService.pickVariantIndex(
            'uid$u|$day|$spot|$action', 2));
      }
      // Across 10 users both variant indices should appear (not all identical).
      expect(indices.length, greaterThan(1));
      expect(indices, containsAll(<int>{0, 1}));
    });

    test('reshuffles across days for the same user', () {
      const uid = 'uidStable', spot = 'bb-hj-8h5h3c-33', action = 'call';
      // Over a span of days, the same user is not pinned to one variant.
      final seen = <int>{};
      for (final day in [
        '2026-10-28',
        '2026-10-29',
        '2026-10-30',
        '2026-10-31',
        '2026-11-01',
      ]) {
        seen.add(DailyCoachLinesService.pickVariantIndex(
            '$uid|$day|$spot|$action', 2));
      }
      expect(seen.length, greaterThan(1));
    });

    test('index is always within [0, count)', () {
      for (var u = 0; u < 50; u++) {
        final idx = DailyCoachLinesService.pickVariantIndex('seed$u', 2);
        expect(idx, inInclusiveRange(0, 1));
      }
    });
  });
}
