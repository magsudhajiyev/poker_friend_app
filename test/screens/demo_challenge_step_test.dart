import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/screens/onboarding/demo_challenge_step.dart';

/// Step 5 (hard paywall): the onboarding demo Daily Challenge spot. These
/// cover the NEW widget — that it presents the teaser and that "Skip for now"
/// advances the flow without launching a hand. (Launching the real runner
/// needs Firebase + a loaded day, out of scope for a widget test; the flag
/// gating lives in OnboardingFlow and is a single isEnabled() guard.)
void main() {
  Future<void> pump(WidgetTester tester, {required VoidCallback onContinue}) {
    return tester.pumpWidget(
      MaterialApp(
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

  testWidgets('shows the teaser: title, play CTA and skip', (tester) async {
    await pump(tester, onContinue: () {});
    // Drain the StepReveal stagger timers so none outlive the test.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text("Try today's challenge"), findsOneWidget);
    expect(find.text('Play a hand'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('Skip advances the flow without launching a hand',
      (tester) async {
    var advanced = 0;
    await pump(tester, onContinue: () => advanced++);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(advanced, 1);
    // No navigation happened — still on the step.
    expect(find.text("Try today's challenge"), findsOneWidget);
  });
}
