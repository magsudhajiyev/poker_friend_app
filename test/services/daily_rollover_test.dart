import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/daily_rollover.dart';

void main() {
  group('DailyRollover', () {
    test('same day, any time: no rollover', () {
      expect(
          DailyRollover.hasRolledOver(
              DateTime(2026, 10, 29), DateTime(2026, 10, 29, 23, 59)),
          isFalse);
    });

    test('after midnight: rolled over, cannot start', () {
      final shown = DateTime(2026, 10, 29);
      final now = DateTime(2026, 10, 30, 0, 0, 1);
      expect(DailyRollover.hasRolledOver(shown, now), isTrue);
      expect(DailyRollover.canStartRun(shown, now), isFalse);
    });

    test('can start on the same day', () {
      expect(
          DailyRollover.canStartRun(
              DateTime(2026, 10, 29), DateTime(2026, 10, 29, 12)),
          isTrue);
    });
  });

  group('RemoteDailySummary.fromEntry', () {
    test('null or empty map gives null', () {
      expect(RemoteDailySummary.fromEntry(null), isNull);
      expect(RemoteDailySummary.fromEntry({}), isNull);
    });

    test('reads score, verdicts, perfect', () {
      final s = RemoteDailySummary.fromEntry(
          {'score': 87.4, 'verdicts': 'cco|c', 'perfect': false})!;
      expect(s.score, 87.4);
      expect(s.verdicts, 'cco|c');
      expect(s.perfect, isFalse);
      expect(s.scoreText, '87.4');
    });

    test('falls back to scoreKey and derives perfect from verdicts', () {
      final s = RemoteDailySummary.fromEntry(
          {'scoreKey': 1000, 'verdicts': 'cc|c'})!;
      expect(s.score, 100);
      expect(s.perfect, isTrue);
      expect(s.scoreText, '100');
    });
  });
}
