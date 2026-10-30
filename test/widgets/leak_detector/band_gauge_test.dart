import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/widgets/leak_detector/band_gauge.dart';

import 'leak_test_harness.dart';

void main() {
  group('BandGauge.markerX / clamp01', () {
    test('keeps the marker fully inside the track', () {
      expect(BandGauge.markerX(-1, 100, 6), 7);
      expect(BandGauge.markerX(2, 100, 6), 93);
      expect(BandGauge.markerX(0.5, 100, 6), 50);
    });

    test('NaN and out-of-range values clamp to 0..1', () {
      expect(BandGauge.clamp01(double.nan), 0);
      expect(BandGauge.clamp01(1.7), 1);
      expect(BandGauge.clamp01(-0.4), 0);
    });

    test('degenerate track width centres the marker', () {
      expect(BandGauge.markerX(0.9, 10, 6), 5);
    });
  });

  group('BandGauge widget', () {
    testWidgets('announces title, value and healthy range', (t) async {
      final handle = t.ensureSemantics();
      await pumpLeakApp(
        t,
        const Scaffold(
          body: BandGauge(
            title: 'Fold to 3-bet',
            value: 0.42,
            bandLow: 0.2,
            bandHigh: 0.3,
            markerColor: Colors.red,
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Fold to 3-bet 42%, healthy range 20% to 30%'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('out-of-range input is clamped in the announcement and paints',
        (t) async {
      final handle = t.ensureSemantics();
      await pumpLeakApp(
        t,
        const Scaffold(
          body: BandGauge(
            title: 'X',
            value: 1.5,
            bandLow: -0.2,
            bandHigh: 1.4,
            markerColor: Colors.red,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('X 100%, healthy range 0% to 100%'),
          findsOneWidget);
      expectNoLayoutErrors(t);
      handle.dispose();
    });

    testWidgets('takes its full width and a fixed small height', (t) async {
      await pumpLeakApp(
        t,
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: BandGauge(
              title: 'X',
              value: 0.5,
              bandLow: 0.2,
              bandHigh: 0.4,
              markerColor: Colors.red,
            ),
          ),
        ),
        size: kSmall,
      );
      final size = t.getSize(find.byType(BandGauge));
      expect(size.width, kSmall.width - 32);
      expect(size.height, lessThan(30));
    });
  });
}
