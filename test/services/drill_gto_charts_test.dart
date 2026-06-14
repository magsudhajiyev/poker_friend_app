import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/drill_gto_charts.dart';

void main() {
  group('DrillGtoCharts range membership', () {
    test('all positions open every pocket pair (incl. small pairs)', () {
      for (final pos in ['EP', 'MP', 'CO', 'BTN', 'SB']) {
        for (final p in ['22', '33', '44', '55', '66', '77']) {
          expect(DrillGtoCharts.isOpen(pos, p), isTrue,
              reason: '$p should open from $pos');
        }
      }
    });

    test('premiums open everywhere, trash nowhere', () {
      for (final pos in ['EP', 'MP', 'CO', 'BTN', 'SB']) {
        expect(DrillGtoCharts.isOpen(pos, 'AA'), isTrue);
        expect(DrillGtoCharts.isOpen(pos, 'AKs'), isTrue);
        expect(DrillGtoCharts.isOpen(pos, '72o'), isFalse);
        expect(DrillGtoCharts.isOpen(pos, '83o'), isFalse);
      }
    });

    test('late position opens hands early position folds', () {
      // K2s and weak offsuit broadways are button opens, not UTG opens
      expect(DrillGtoCharts.isOpen('BTN', 'K2s'), isTrue);
      expect(DrillGtoCharts.isOpen('EP', 'K2s'), isFalse);
      expect(DrillGtoCharts.isOpen('BTN', 'A2o'), isTrue);
      expect(DrillGtoCharts.isOpen('EP', 'A2o'), isFalse);
    });
  });

  group('DrillGtoCharts coverage', () {
    test('opening ranges widen from early to late position', () {
      final ep = DrillGtoCharts.coverage('EP');
      final mp = DrillGtoCharts.coverage('MP');
      final co = DrillGtoCharts.coverage('CO');
      final btn = DrillGtoCharts.coverage('BTN');
      expect(ep, lessThan(mp));
      expect(mp, lessThan(co));
      expect(co, lessThan(btn));
    });

    test('coverage values land in sane ranges', () {
      expect(DrillGtoCharts.coverage('EP'), inInclusiveRange(14, 22));
      expect(DrillGtoCharts.coverage('BTN'), inInclusiveRange(40, 52));
    });
  });

  group('DrillGtoCharts widen / tighten', () {
    test('widen increases coverage and is a superset', () {
      final base = DrillGtoCharts.openRange('EP');
      final wide = DrillGtoCharts.widen(base, 10);
      expect(wide.length, greaterThan(base.length));
      expect(base.every(wide.contains), isTrue);
      expect(DrillGtoCharts.coverageOf(wide),
          greaterThan(DrillGtoCharts.coverageOf(base)));
    });

    test('tighten decreases coverage and is a subset', () {
      final base = DrillGtoCharts.openRange('BTN');
      final tight = DrillGtoCharts.tighten(base, 10);
      expect(tight.length, lessThan(base.length));
      expect(tight.every(base.contains), isTrue);
      expect(DrillGtoCharts.coverageOf(tight),
          lessThan(DrillGtoCharts.coverageOf(base)));
    });

    test('widen adds the strongest excluded hands first', () {
      final base = DrillGtoCharts.openRange('EP');
      final wide = DrillGtoCharts.widen(base, 2);
      // A small widen should not be pulling in total trash like 72o
      expect(wide.contains('72o'), isFalse);
    });
  });
}
