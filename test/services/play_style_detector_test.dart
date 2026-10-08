import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/play_style_detector.dart';

void main() {
  group('PlayStyleDetector.detectPlayStyle', () {
    String styleFor({
      required double vpip,
      required double pfr,
      double threeBet = 0,
      double aggressionFactor = 0,
      int? handsPlayed = 100,
    }) {
      return PlayStyleDetector.detectPlayStyle(
        vpip: vpip,
        pfr: pfr,
        threeBet: threeBet,
        aggressionFactor: aggressionFactor,
        handsPlayed: handsPlayed,
      )['style']!;
    }

    test('under 50 hands returns Unknown regardless of stats', () {
      expect(styleFor(vpip: 20, pfr: 15, handsPlayed: 49), 'Unknown');
      expect(styleFor(vpip: 20, pfr: 15, handsPlayed: 0), 'Unknown');
    });

    test('zeroed stats return Unknown even with a full sample', () {
      expect(styleFor(vpip: 0, pfr: 0, handsPlayed: 500), 'Unknown');
    });

    test('REGRESSION: 762-hand profile in tree hole gets a style, not Unknown',
        () {
      // Live bug 2026-08-04: VPIP 28.35 / PFR 18.9 / gap 9.4 / AF 2.0 /
      // 3-bet 24 matched no branch -> Unknown -> home tile showed "762/50".
      // Misses Balanced (VPIP cap 28), strict LAG (gap cap 8), fallback LAG
      // (AF floor 2.5) and moderate LAG (VPIP floor 30).
      final style = styleFor(
        vpip: 28.35,
        pfr: 18.9,
        threeBet: 24.0,
        aggressionFactor: 2.0,
        handsPlayed: 762,
      );
      expect(style, isNot('Unknown'));
      // Loose + aggressive coarse quadrant.
      expect(style, 'LAG');
    });

    test('50+ hands never returns Unknown across a stat sweep', () {
      for (double vpip = 1; vpip <= 80; vpip += 2.7) {
        for (double pfr = 0; pfr <= vpip; pfr += 3.1) {
          for (double af = 0; af <= 6; af += 0.9) {
            final style = styleFor(
              vpip: vpip,
              pfr: pfr,
              threeBet: 5,
              aggressionFactor: af,
              handsPlayed: 200,
            );
            expect(style, isNot('Unknown'),
                reason: 'hole at vpip=$vpip pfr=$pfr af=$af');
          }
        }
      }
    });

    test('canonical archetypes still classify unchanged', () {
      expect(
          styleFor(vpip: 45, pfr: 30, threeBet: 14, aggressionFactor: 4.5),
          'Maniac');
      expect(
          styleFor(vpip: 40, pfr: 5, threeBet: 1, aggressionFactor: 0.5),
          'Calling Station');
      expect(
          styleFor(vpip: 12, pfr: 9, threeBet: 3, aggressionFactor: 1.5),
          'Nit');
      expect(
          styleFor(vpip: 28, pfr: 22, threeBet: 9, aggressionFactor: 3.5),
          'LAG');
      expect(
          styleFor(vpip: 18, pfr: 15, threeBet: 8, aggressionFactor: 3.0),
          'TAG');
      expect(
          styleFor(vpip: 24, pfr: 20, threeBet: 8, aggressionFactor: 3.0),
          'Balanced');
    });

    test('coarse fallback quadrants', () {
      // Tight + passive hole -> Tight-Passive
      expect(
          styleFor(vpip: 18, pfr: 4, threeBet: 4, aggressionFactor: 0.4),
          anyOf('Tight-Passive', 'Nit'));
      // Loose + passive hole -> Loose-Passive
      expect(
          styleFor(vpip: 30, pfr: 16, threeBet: 4, aggressionFactor: 1.2),
          anyOf('Loose-Passive', 'Calling Station'));
    });
  });
}
