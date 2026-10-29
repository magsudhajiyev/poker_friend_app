import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/screens/onboarding/daily_challenge_info_step.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Headers may be rendered upper-cased by the widgets.
Finder _hdr(String t) => find.byWidgetPredicate(
    (w) => w is Text && (w.data ?? '').toLowerCase() == t.toLowerCase(),
    skipOffstage: false);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester,
      {required VoidCallback onContinue, bool reduceMotion = false}) {
    return tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: DailyChallengeInfoStep(onContinue: onContinue),
      ),
    );
  }

  // Idle loops never settle: pump past the staggered entrance in bounded steps.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  void setSize(WidgetTester tester, Size s) {
    tester.view.physicalSize = s;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows title, CTA, streak and leaderboard headers',
      (tester) async {
    setSize(tester, const Size(393, 852));
    await pump(tester, onContinue: () {});
    await settle(tester);
    final l10n = AppLocalizations.of(
        tester.element(find.byType(DailyChallengeInfoStep)));
    expect(find.text('Your daily poker workout'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(_hdr(l10n.onbStreakHeader), findsOneWidget);
    expect(_hdr(l10n.onbLeaderboardHeader), findsOneWidget);
  });

  testWidgets('reduced motion settles', (tester) async {
    setSize(tester, const Size(393, 852));
    await pump(tester, onContinue: () {}, reduceMotion: true);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('320x568 @1.3 text scale does not overflow', (tester) async {
    setSize(tester, const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester, onContinue: () {});
    await settle(tester);
    expect(tester.takeException(), isNull);
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, const Offset(0, -2000));
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('CTA calls onContinue', (tester) async {
    setSize(tester, const Size(393, 852));
    var n = 0;
    await pump(tester, onContinue: () => n++);
    await settle(tester);
    await tester.tap(find.text('Get started'));
    expect(n, 1);
  });
}
