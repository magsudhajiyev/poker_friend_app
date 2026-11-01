import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/design_system/components/overlays/raise_snap_overlay.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/services/sizing_history_store.dart';

List<SnapPoint> pre() => RaiseSnapOverlay.preflopSnapPoints(
    minRaise: 4, bigBlind: 2, potAmount: 20, maxBet: 200, isCashGame: true);

void main() {
  test('no suggestion = identical points (same list)', () {
    final p = pre();
    expect(identical(RaiseSnapOverlay.applySuggestion(p, null, sameAsLastLabel: 'S'), p), isTrue);
    expect(
        identical(
            RaiseSnapOverlay.applySuggestion(p, SizingSuggestion.none, sameAsLastLabel: 'S'), p),
        isTrue);
    // preselect alone never adds a snap
    expect(
        RaiseSnapOverlay.applySuggestion(p, const SizingSuggestion(preselect: 7),
                sameAsLastLabel: 'S')
            .length,
        p.length);
  });

  test('sameAsLast adds exactly one sorted snap', () {
    final p = pre();
    final out = RaiseSnapOverlay.applySuggestion(
        p, const SizingSuggestion(sameAsLast: 11.3), sameAsLastLabel: 'Same as last');
    expect(out.length, p.length + 1);
    expect(out.where((e) => e.isSuggestion).length, 1);
    final amounts = out.map((e) => e.amount).toList();
    expect(amounts, [...amounts]..sort());
    expect(out.first.label, 'Min');
    expect(out.last.label, 'All-In');
  });

  test('out of range or duplicate amounts add nothing', () {
    final p = pre();
    for (final v in [1.0, 4.0, 200.0, 999.0, p[2].amount]) {
      expect(
          RaiseSnapOverlay.applySuggestion(p, SizingSuggestion(sameAsLast: v),
                  sameAsLastLabel: 'S')
              .length,
          p.length,
          reason: '$v');
    }
  });

  test('all-in-only ladder is untouched', () {
    final p = RaiseSnapOverlay.allInOnlySnapPoints(maxBet: 30);
    expect(
        RaiseSnapOverlay.applySuggestion(p, const SizingSuggestion(sameAsLast: 10),
            sameAsLastLabel: 'S'),
        p);
  });

  test('usualIndexFor and numpadPrefill', () {
    final p = pre();
    final target = p[2].amount;
    expect(RaiseSnapOverlay.usualIndexFor(p, SizingSuggestion(preselect: target)), 2);
    expect(RaiseSnapOverlay.usualIndexFor(p, null), isNull);
    expect(RaiseSnapOverlay.usualIndexFor(p, const SizingSuggestion(preselect: 1000)), isNull);
    expect(RaiseSnapOverlay.numpadPrefill(const SizingSuggestion(preselect: 9), min: 4, max: 50), 9);
    expect(RaiseSnapOverlay.numpadPrefill(const SizingSuggestion(preselect: 3), min: 4, max: 50), isNull);
    expect(RaiseSnapOverlay.numpadPrefill(null, min: 4, max: 50), isNull);
  });

  Widget host(List<SnapPoint> pts, SizingSuggestion? s) => MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(children: [
            RaiseSnapOverlay(
              snapPoints: pts,
              currentAmount: pts.first.amount,
              activeSnapIndex: 0,
              dragProgress: 0,
              actionLabel: 'RAISE',
              formattedAmount: '4',
              isCashGame: true,
              suggestion: s,
            ),
          ]),
        ),
      );

  testWidgets('renders; "Your usual" caption only with a matching preselect', (t) async {
    final p = pre();
    await t.pumpWidget(host(p, null));
    expect(find.text('Your usual'), findsNothing);
    await t.pumpWidget(host(p, SizingSuggestion(preselect: p[2].amount)));
    expect(find.text('Your usual'), findsOneWidget);
  });
}
