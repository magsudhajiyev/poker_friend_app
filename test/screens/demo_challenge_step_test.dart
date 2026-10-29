import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/coach_persona.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/screens/onboarding/demo_challenge_step.dart';

/// Step 5 (hard paywall): the onboarding demo Daily Challenge spot. These
/// cover the NEW widget — that it presents the teaser and that "Skip for now"
/// advances the flow without launching a hand. (Launching the real runner
/// needs Firebase + a loaded day, out of scope for a widget test; the flag
/// gating lives in OnboardingFlow and is a single isEnabled() guard.)
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
        home: DemoChallengeStep(onContinue: onContinue),
      ),
    );
  }

  // Idle bob / flame flicker loop forever, so pumpAndSettle can never finish.
  // Pump past the ~2.5 s entrance (and CoachPersonas.load) in bounded steps.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows the teaser: title, play CTA and skip', (tester) async {
    await pump(tester, onContinue: () {});
    // Drain the StepReveal stagger timers so none outlive the test.
    await settle(tester);

    expect(find.text("Try today's challenge"), findsOneWidget);
    expect(find.text('Play a hand'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('Skip advances the flow without launching a hand',
      (tester) async {
    var advanced = 0;
    await pump(tester, onContinue: () => advanced++);
    await settle(tester);

    await tester.tap(find.text('Skip for now'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(advanced, 1);
    // No navigation happened — still on the step.
    expect(find.text("Try today's challenge"), findsOneWidget);
  });

  testWidgets('reduced motion stops every loop (pumpAndSettle completes)',
      (tester) async {
    await pump(tester, onContinue: () {}, reduceMotion: true);
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));
    expect(find.text("Try today's challenge"), findsOneWidget);
  });

  testWidgets('no overflow at 320x568 with textScaler 1.3', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: DemoChallengeStep(onContinue: () {}),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    // Scroll to the bottom: lower cards must lay out cleanly too.
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -2000));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a coach tile shows that persona greeting',
      (tester) async {
    await pump(tester, onContinue: () {});
    await settle(tester);

    final nova = CoachPersonas.nova;
    expect(find.text(nova.greeting), findsNothing);
    final tile = find.text(nova.name).first;
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    await tester.pump();
    await tester.pump(const Duration(seconds: 6)); // typewriter finishes
    // TypewriterBubble renders the text twice (visible + invisible sizer).
    expect(find.text(nova.greeting), findsWidgets);
  });

  // Section headers render upper-cased in some widgets; match ignoring case.
  Finder header(String text) => find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').toLowerCase() == text.toLowerCase());

  testWidgets('shows How it works with steps; no streak/leaderboard',
      (tester) async {
    await pump(tester, onContinue: () {});
    await settle(tester);
    final l10n =
        AppLocalizations.of(tester.element(find.byType(DemoChallengeStep)));
    await tester.ensureVisible(header(l10n.onbFactsHeader));
    await tester.pump();

    expect(header(l10n.onbFactsHeader), findsOneWidget);
    expect(find.text(l10n.onbFactSpots), findsOneWidget);
    expect(find.text(l10n.onbFactCoach), findsOneWidget);
    expect(find.text(l10n.onbFactOnce), findsOneWidget);
    expect(header('Build a streak'), findsNothing);
    expect(header('Daily leaderboard'), findsNothing);
  });
}
