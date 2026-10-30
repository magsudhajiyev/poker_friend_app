import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/services/leak_engine.dart';
import 'package:poker_logger/services/leak_report_service.dart';
import 'package:poker_logger/services/range_shape_service.dart';

/// Full dumps (with `creator:` chains) of every framework error this test
/// raised; the plain exception from takeException() has no widget info.
final List<String> leakErrorLog = [];

const kPhone = Size(390, 844);
const kSmall = Size(320, 640);

/// Pumps [home] in a localized MaterialApp at [size] with [scale] text.
Future<void> pumpLeakApp(
  WidgetTester t,
  Widget home, {
  Size size = kPhone,
  double scale = 1.0,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  leakErrorLog.clear();
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    leakErrorLog.add(details.toString());
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
  await t.pumpWidget(MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  ));
  await t.pump();
}

const kLongTitle =
    'Calling too often out of position on wet flop boards when facing continuation bets';

LeakExample ex(int n, {String? cards = 'A♠K♦', bool texture = true}) =>
    LeakExample('s1:$n',
        posGroup: 'EP',
        holeCards: cards,
        textureLabel: texture ? 'wet board' : null,
        strengthLabel: 'top pair+');

LeakFinding finding(
  String id,
  String title, {
  double value = 0.78,
  double low = 0.45,
  double high = 0.65,
  int n = 60,
  int min = 30,
  LeakVerdict verdict = LeakVerdict.confirmed,
  bool above = true,
  List<LeakExample> examples = const [],
  List<LeakSlice> slices = const [],
}) =>
    LeakFinding(
      id: id,
      title: title,
      value: value,
      bandLow: low,
      bandHigh: high,
      sampleCount: n,
      minSample: min,
      verdict: verdict,
      aboveBand: above,
      meaning: 'You fold to a 3-bet far more than the typical player does, '
          'which means opponents can profitably 3-bet you with almost any two cards.',
      cost: 'Every fold hands the opener the pot without a fight.',
      fix: 'Defend more of your strong hands and mix in calls and 4-bets.',
      examples: examples,
      slices: slices,
    );

List<LeakExample> manyExamples() => [
      ex(11),
      ex(12, cards: 'Q♥Q♣'),
      ex(13, cards: '10♦J♣'),
      ex(14, texture: false),
      ex(15, cards: null),
    ];

LeakReport fakeReport({List<LeakFinding>? extra}) => LeakReport(
      handsAnalyzed: 240,
      coachSummary: 'Your biggest leak is folding to 3-bets.',
      findings: [
        finding('fold_to_3bet', 'Folding too much to 3-bets',
            examples: manyExamples(),
            slices: const [
              LeakSlice('EP', 0.82, 24, flagged: true),
              LeakSlice('BTN', 0.51, 20),
            ]),
        finding('postflop_call', kLongTitle,
            value: 0.2,
            low: 0.3,
            high: 0.5,
            above: false,
            verdict: LeakVerdict.emerging,
            examples: [ex(21)]),
        finding('bb_vs_steal', 'Defending the big blind vs steals',
            value: 0.7,
            low: 0.4,
            high: 0.6,
            verdict: LeakVerdict.emerging),
        for (var i = 0; i < 4; i++)
          finding('healthy_$i',
              i == 2 ? 'A very long healthy detector title that wraps' : 'Healthy $i',
              value: 0.3,
              low: 0.2,
              high: 0.4,
              verdict: LeakVerdict.healthy),
        for (var i = 0; i < 3; i++)
          finding('locked_$i', 'Locked detector $i',
              n: 5 + i * 5, min: 30, verdict: LeakVerdict.insufficientData),
        ...?extra,
      ],
      positionNets: const [
        PositionNet('EP', -120, 40),
        PositionNet('MP', 15, 30),
        PositionNet('CO', 60, 35),
        PositionNet('BTN', 220, 50),
        PositionNet('SB', -40, 30),
        PositionNet('BB', -85, 55),
      ],
      worstSpots: const [
        SpotNet('BB vs BTN steal with a very long descriptive label', -85, 30, 40),
        SpotNet('EP at 40BB', -60, 20, 40),
      ],
    );

LeakReportBundle fakeBundle({LeakReport? report}) {
  final r = report ?? fakeReport();
  final refs = <String, Map<String, dynamic>>{};
  for (final f in r.findings) {
    for (final e in f.examples) {
      // 's1:15' left out on purpose -> "unavailable" row.
      if (e.ref != 's1:15') refs[e.ref] = {'handNumber': e.handNumber};
    }
  }
  return LeakReportBundle(r, refs);
}

PositionShape shapePos(String pos, int spots, {int devs = 0}) => PositionShape(
      posGroup: pos,
      sampledSpots: spots,
      playerOpenFreq: 0.31,
      chartOpenPct: 0.27,
      missedOpens: [
        for (var i = 0; i < devs; i++)
          ShapeCellDeviation(handClass: 'A${i + 2}s', spots: 5, offActions: 4 + i),
      ],
      looseOpens: [
        for (var i = 0; i < devs; i++)
          ShapeCellDeviation(handClass: '7${i + 2}o', spots: 4, offActions: 3 + i),
      ],
    );

RangeShapeReport fakeShape() => RangeShapeReport([
      shapePos('EP', 60, devs: 5),
      shapePos('MP', 25),
      shapePos('CO', 8),
      shapePos('BTN', 12),
      shapePos('SB', 0),
    ]);

/// Fails the test on any layout/overflow exception raised so far.
void expectNoLayoutErrors(WidgetTester t, [String? reason]) {
  final e = t.takeException();
  final detail = leakErrorLog.isEmpty ? '$e' : leakErrorLog.join('\n---\n');
  expect(e, isNull, reason: reason ?? 'unexpected exception: $detail');
  leakErrorLog.clear();
}
