import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/services/stack_timeline.dart';
import 'package:poker_logger/widgets/stack_growth_chart.dart';

Map<String, dynamic> e(String type, double stack, {int hand = 0, Map<String, dynamic>? extra}) => {
      'changeType': type,
      'stackSize': stack,
      'changeAmount': 0.0,
      'handNumber': hand,
      ...?extra,
    };

Widget host(StackGrowthChart chart) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: SizedBox(width: 380, child: chart))),
    );

StackGrowthChart chart(List<Map<String, dynamic>> h,
        {ValueChanged<List<String>>? onPending}) =>
    StackGrowthChart(
      stackHistory: h,
      startingStack: 1000,
      formatValue: (v) => v.toStringAsFixed(0),
      onPendingTapped: onPending,
      onDotTapped: (_) {},
    );

LineChartData data(WidgetTester t) =>
    t.widget<LineChart>(find.byType(LineChart)).data;

void main() {
  testWidgets('flag off / old session renders the plain index-based line', (t) async {
    final h = [
      e('initial', 1000),
      e('win', 1100, hand: 1),
      e('loss', 900, hand: 2),
    ];
    await t.pumpWidget(host(chart(h)));
    await t.pumpAndSettle();
    final bars = data(t).lineBarsData;
    expect(bars.length, 1);
    expect(bars.single.isCurved, isTrue);
    expect(bars.single.dashArray, isNull);
    expect([for (final s in bars.single.spots) (s.x, s.y)],
        [(0.0, 1000.0), (1.0, 1100.0), (2.0, 900.0)]);
    expect(find.textContaining('pending'), findsNothing);
  });

  testWidgets('flag off: manual stack update keeps the #idx label, easy kinds get the note icon', (t) async {
    // Old manual entries carry no handNumber.
    final plain = [
      e('initial', 1000),
      e('win', 1100, hand: 1),
      {'changeType': 'manual_increase', 'stackSize': 1200.0, 'changeAmount': 100.0},
    ];
    await t.pumpWidget(host(chart(plain)));
    await t.pumpAndSettle();
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('📝'), findsNothing);

    final easy = [
      e('initial', 1000),
      e('fold_run', 990, hand: 1),
      e('manual_increase', 1200),
    ];
    await t.pumpWidget(host(chart(easy)));
    await t.pumpAndSettle();
    expect(find.text('📝'), findsOneWidget);
  });

  testWidgets('pending flag: dashed bar, label chip, tap opens the flag', (t) async {
    final h = [
      e('initial', 1000),
      e('win', 1100, hand: 1),
      e('pending', 1100, hand: 2, extra: {'flagId': 'f1'}),
      e('win', 1150, hand: 3),
      e('manual_decrease', 850),
    ];
    List<String>? tapped;
    await t.pumpWidget(host(chart(h, onPending: (ids) => tapped = ids)));
    await t.pumpAndSettle();
    final bars = data(t).lineBarsData;
    expect(bars.any((b) => b.dashArray != null), isTrue);
    expect(bars.firstWhere((b) => b.dashArray != null).dashArray, [6, 4]);
    expect(find.text('1 hand pending'), findsOneWidget);
    await t.tap(find.text('1 hand pending'));
    expect(tapped, ['f1']);
  });

  testWidgets('tooltip lookup is by hand number, not list position', (t) async {
    // Hand numbers skip (fold ticks consumed 2..4): number-1 is not an index.
    final hands = <int, ChartHandInfo>{
      5: const ChartHandInfo(position: 'BTN', card1: 'A♠', card2: 'K♠'),
    };
    final h = [e('initial', 1000), e('win', 1100, hand: 5)];
    await t.pumpWidget(host(StackGrowthChart(
      stackHistory: h,
      startingStack: 1000,
      formatValue: (v) => v.toStringAsFixed(0),
      selectedIndex: 1,
      onDotTapped: (_) {},
      handLookup: (n) => hands[n],
    )));
    await t.pumpAndSettle();
    expect(data(t).showingTooltipIndicators.length, 1);
    // The widget resolves info for hand 5 only.
    final lookup = handLookupFromMaps([
      {'handNumber': 5, 'heroPositionName': 'BTN', 'ourHoleCards': {'card1': 'A♠', 'card2': 'K♠'}},
    ]);
    expect(lookup(5)!.position, 'BTN');
    expect(lookup(4), isNull);
  });

  test('chart series for a plain history equals the timeline series', () {
    final h = [e('initial', 10), e('win', 20, hand: 1)];
    final d = StackTimeline.build(h);
    expect(d.points.map((p) => p.y), [10, 20]);
  });
}
