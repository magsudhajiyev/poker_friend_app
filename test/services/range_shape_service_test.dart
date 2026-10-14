import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/drill_gto_charts.dart';
import 'package:poker_logger/services/range_grid_service.dart';
import 'package:poker_logger/services/range_shape_service.dart';

/// RANGE SHAPE analysis (retention doc R11): player's RFI cells vs the
/// app's baseline opening charts — missed opens, loose opens, honesty
/// thresholds. Pure tests, no storage.
void main() {
  RangeCellAggregate agg(
    String hc, {
    int raise = 0,
    int allIn = 0,
    int call = 0,
    int fold = 0,
    int check = 0,
  }) =>
      RangeCellAggregate(
        handClass: hc,
        raiseCount: raise,
        allInCount: allIn,
        callCount: call,
        foldCount: fold,
        checkCount: check,
      );

  group('RangeShapeService.analyzePosition', () {
    test('missed open: chart opens it, player keeps folding it', () {
      assert(DrillGtoCharts.isOpen('BTN', 'A5s'));
      final shape = RangeShapeService.analyzePosition(
        posGroup: 'BTN',
        aggregates: {'A5s': agg('A5s', fold: 3)},
      );
      expect(shape.missedOpens.single.handClass, 'A5s');
      expect(shape.missedOpens.single.offActions, 3);
      expect(shape.looseOpens, isEmpty);
    });

    test('loose open: chart folds it, player keeps opening it', () {
      assert(!DrillGtoCharts.isOpen('EP', '72o'));
      final shape = RangeShapeService.analyzePosition(
        posGroup: 'EP',
        aggregates: {'72o': agg('72o', raise: 2, allIn: 1)},
      );
      expect(shape.looseOpens.single.handClass, '72o');
      expect(shape.looseOpens.single.offActions, 3);
      expect(shape.missedOpens, isEmpty);
    });

    test('single-spot cells are NEVER findings (sample honesty)', () {
      final shape = RangeShapeService.analyzePosition(
        posGroup: 'BTN',
        aggregates: {
          'A5s': agg('A5s', fold: 1), // chart open, folded once — noise
          '72o': agg('72o', raise: 1), // chart fold, opened once — noise
        },
      );
      expect(shape.missedOpens, isEmpty);
      expect(shape.looseOpens, isEmpty);
      expect(shape.sampledSpots, 2, reason: 'still counted toward volume');
    });

    test('mixed cells below the deviation rate are not flagged', () {
      // 50/50 open-fold on a chart-open hand: inconsistent, not a leak.
      final shape = RangeShapeService.analyzePosition(
        posGroup: 'BTN',
        aggregates: {'A5s': agg('A5s', raise: 2, fold: 2)},
      );
      expect(shape.missedOpens, isEmpty);
    });

    test('open frequency and chart coverage are computed correctly', () {
      final shape = RangeShapeService.analyzePosition(
        posGroup: 'BTN',
        aggregates: {
          'AA': agg('AA', raise: 4),
          'T2o': agg('T2o', fold: 4),
        },
      );
      expect(shape.playerOpenFreq, closeTo(0.5, 0.001));
      expect(shape.chartOpenPct, greaterThan(0.3),
          reason: 'BTN chart opens a wide range');
    });

    test('later positions have wider charts (sanity of the baseline)', () {
      double coverage(String pos) => RangeShapeService.analyzePosition(
            posGroup: pos,
            aggregates: const {},
          ).chartOpenPct;
      expect(coverage('BTN'), greaterThan(coverage('CO')));
      expect(coverage('CO'), greaterThan(coverage('EP')));
    });

    test('sufficiency gate at $RangeShapeService.minPositionSpots spots',
        () {
      final thin = RangeShapeService.analyzePosition(
        posGroup: 'CO',
        aggregates: {'AA': agg('AA', raise: 5)},
      );
      expect(thin.sufficient, isFalse);

      final enough = RangeShapeService.analyzePosition(
        posGroup: 'CO',
        aggregates: {
          for (var i = 0; i < 5; i++)
            'A${'KQJT9'[i]}s': agg('A${'KQJT9'[i]}s', raise: 4),
        },
      );
      expect(enough.sampledSpots, 20);
      expect(enough.sufficient, isTrue);
    });

    test('worst offenders sort first and cap at maxCells', () {
      final aggs = <String, RangeCellAggregate>{
        // 10 chart-open BTN hands, folded with increasing volume.
        for (var i = 2; i <= 11; i++)
          _btnOpenHand(i): agg(_btnOpenHand(i), fold: i),
      };
      final shape =
          RangeShapeService.analyzePosition(posGroup: 'BTN', aggregates: aggs);
      expect(shape.missedOpens.length, RangeShapeService.maxCells);
      expect(shape.missedOpens.first.offActions, 11, reason: 'biggest first');
    });
  });

  group('RangeShapeService.classifyCell (mini-grid paint)', () {
    test('all five classifications', () {
      expect(
          RangeShapeService.classifyCell(inChart: true, agg: null), 'noData');
      expect(
          RangeShapeService.classifyCell(
              inChart: true, agg: agg('A5s', raise: 3)),
          'alignedOpen');
      expect(
          RangeShapeService.classifyCell(
              inChart: true, agg: agg('A5s', fold: 3)),
          'missed');
      expect(
          RangeShapeService.classifyCell(
              inChart: false, agg: agg('72o', raise: 3)),
          'loose');
      expect(
          RangeShapeService.classifyCell(
              inChart: false, agg: agg('72o', fold: 3)),
          'alignedFold');
    });

    test('below minCellSpots always paints as noData', () {
      expect(
          RangeShapeService.classifyCell(
              inChart: true, agg: agg('A5s', fold: 1)),
          'noData');
    });
  });
}

/// A hand the BTN chart definitely opens, varied by index (suited aces).
String _btnOpenHand(int i) {
  const hands = [
    'A2s', 'A3s', 'A4s', 'A5s', 'A6s', 'A7s',
    'A8s', 'A9s', 'ATs', 'AJs', 'AQs', 'AKs',
  ];
  return hands[i % hands.length];
}
