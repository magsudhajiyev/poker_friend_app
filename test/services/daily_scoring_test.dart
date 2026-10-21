import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/daily_scoring.dart';

void main() {
  group('hand accuracy', () {
    test('verdict values: BEST 1, GOOD 0.5, LEAK 0', () {
      expect(DailyScoring.handAccuracy('c', const [1]), 1.0);
      expect(DailyScoring.handAccuracy('o', const [1]), 0.5);
      expect(DailyScoring.handAccuracy('m', const [1]), 0.0);
    });

    test('pot weighting: a big-pot leak costs more than a small-pot one', () {
      // open (2.5) BEST, vs 3-bet (12) BEST, flop (19) GOOD, vs bet (26) LEAK
      final acc =
          DailyScoring.handAccuracy('ccom', const [2.5, 12, 19, 26]);
      expect(acc, closeTo((2.5 + 12 + 9.5) / 59.5, 1e-9)); // ≈ 0.403
      final earlyLeak = DailyScoring.handAccuracy('mc', const [2.5, 26]);
      final lateLeak = DailyScoring.handAccuracy('cm', const [2.5, 26]);
      expect(earlyLeak, greaterThan(lateLeak));
    });

    test('weights below 1 count as 1 (no zero-weight decisions)', () {
      expect(DailyScoring.handAccuracy('cm', const [0, 0]), 0.5);
    });

    test('line length does not inflate the score', () {
      // A short perfect line and a long perfect line are both 100%.
      expect(DailyScoring.handAccuracy('c', const [2.5]), 1.0);
      expect(DailyScoring.handAccuracy('ccccc', const [2.5, 12, 19, 26, 60]),
          1.0);
    });
  });

  group('day accuracy', () {
    test('every hand counts the same, whatever its length', () {
      // Hand 1: 1 decision LEAK (0%), hand 2: 4 decisions all BEST (100%).
      expect(DailyScoring.accuracy('m|cccc', const [2.5, 2.5, 12, 19, 26]),
          50.0);
    });

    test('weights are aligned across hands', () {
      final pct = DailyScoring.accuracy('cm|o', const [1, 3, 5]);
      // hand1 = 1/4 = 0.25, hand2 = 0.5 → mean 0.375
      expect(pct, 37.5);
    });

    test('no separator = one hand (single-hand day / legacy RNG run)', () {
      expect(DailyScoring.handsOf('ccom'), ['ccom']);
      // Legacy RNG 'ccomm' (weights 1) scores the same either way: 2.5 / 5.
      expect(DailyScoring.accuracy('ccomm'), 50.0);
      expect(DailyScoring.accuracy('c|c|o|m|m'), 50.0);
      expect(DailyScoring.accuracy('ccccc'), 100.0);
    });

    test('a single authored hand keeps its pot weights', () {
      expect(DailyScoring.accuracy('ccom', const [2.5, 12, 19, 26]), 40.3);
    });

    test('rounded to one decimal', () {
      expect(DailyScoring.accuracy('cco'), 83.3);
    });

    test('empty run scores 0', () {
      expect(DailyScoring.accuracy(''), 0);
    });
  });

  test('perfect = every decision of every hand is BEST', () {
    expect(DailyScoring.isPerfect('ccc|cc|c'), isTrue);
    expect(DailyScoring.isPerfect('ccc|co|c'), isFalse);
    expect(DailyScoring.isPerfect(''), isFalse);
  });

  test('scoreKey orders by accuracy with one decimal of precision', () {
    expect(DailyScoring.scoreKey(100), 1000);
    expect(DailyScoring.scoreKey(87.4), 874);
    expect(DailyScoring.scoreKey(87.5) > DailyScoring.scoreKey(87.4), isTrue);
  });

  test('decisionCount ignores separators', () {
    expect(DailyScoring.decisionCount('ccoc|cc|c'), 7);
  });
}
