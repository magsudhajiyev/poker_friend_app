import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/widgets/leak_detector/health_tab.dart';
import 'package:poker_logger/widgets/leak_detector/ranges_tab.dart';

import 'leak_test_harness.dart';

void main() {
  testWidgets('HealthTab: no Drill button when onDrill is null', (t) async {
    await pumpLeakApp(
        t,
        Scaffold(
          body: SingleChildScrollView(
            child: HealthTab(
                report: fakeReport(), fixed: const [], onMoneyInfo: () {}),
          ),
        ));
    await t.pumpAndSettle();
    expect(find.text('Drill'), findsNothing);
    expectNoLayoutErrors(t);
  });

  testWidgets('HealthTab: Drill button shown when onDrill given', (t) async {
    await pumpLeakApp(
        t,
        Scaffold(
          body: SingleChildScrollView(
            child: HealthTab(
                report: fakeReport(),
                fixed: const [],
                onDrill: (_) {},
                onMoneyInfo: () {}),
          ),
        ));
    await t.pumpAndSettle();
    expect(find.text('Drill'), findsWidgets);
  });

  testWidgets('RangesTab: no Practice button when onPractice is null',
      (t) async {
    await pumpLeakApp(
        t,
        Scaffold(
          body: SingleChildScrollView(
            child: RangesTab(
              shape: fakeShape(),
              selectedPos: 'EP',
              onSelectPos: (_) {},
              onOpenGrid: (_) {},
              onInfo: () {},
            ),
          ),
        ));
    await t.pumpAndSettle();
    expect(find.text('Practice opens'), findsNothing);
    expectNoLayoutErrors(t);
  });
}
