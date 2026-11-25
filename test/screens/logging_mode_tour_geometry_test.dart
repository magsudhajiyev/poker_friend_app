import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/design_system/constants/decorations.dart';
import 'package:poker_logger/l10n/app_localizations.dart';
import 'package:poker_logger/onboarding/onboarding_state.dart';
import 'package:poker_logger/onboarding/onboarding_tour.dart';
import 'package:poker_logger/screens/logging_mode_selection_screen.dart';
import 'package:poker_logger/services/feature_flag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 1 of the in-app tour on the compact-row Choose mode sheet: the
/// bubble and the Skip pill must never cover the Full logging row.
void main() {
  tearDown(() {
    OnboardingState.isOnboardingActive = false;
    OnboardingState.currentPhase = 0;
  });

  test('spotlight hugs the row corners (row radius + focus padding)', () {
    expect(LoggingModeTour.spotlightRadius,
        AppDecorations.radiusXl + LoggingModeTour.spotlightPadding);
  });

  for (final size in const [Size(320, 568), Size(430, 932)]) {
    for (final scale in const [1.0, 1.3]) {
      for (final drills in const ['on', 'off']) {
        testWidgets('$size x$scale drills $drills: bubble above row, skip clear',
            (t) async {
          SharedPreferences.setMockInitialValues({});
          await FeatureFlagService.applyRemote({
            'training_drills': drills,
            'single_hand': 'off',
            'tracked_session': 'off',
          });
          OnboardingState.isOnboardingActive = true;
          OnboardingState.currentPhase = 1;
          t.view.physicalSize = size * 3;
          t.view.devicePixelRatio = 3;
          addTearDown(t.view.reset);
          await t.pumpWidget(MaterialApp(
            builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoggingModeSelectionScreen(),
          ));
          await t.pump();
          await t.pump(const Duration(milliseconds: 700));
          for (var i = 0; i < 10; i++) {
            await t.pump(const Duration(milliseconds: 200));
          }
          final row = t.getRect(find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_ModeRow' && w.key is GlobalKey));
          final bubble = t.getRect(
              find.ancestor(of: find.text('Got it'), matching: find.byType(Container)).last);
          final skip = t.getRect(find.text('Skip tour'));
          final screen = Offset.zero & size;

          expect(row.height, greaterThanOrEqualTo(64));
          expect(screen.contains(row.topLeft) && screen.contains(row.bottomRight),
              isTrue);
          // Bubble: on screen, wholly above the row's spotlight.
          expect(bubble.top, greaterThanOrEqualTo(0));
          expect(bubble.bottom,
              lessThanOrEqualTo(row.top - LoggingModeTour.spotlightPadding));
          // Skip pill: on screen and never over the row.
          expect(screen.contains(skip.topLeft), isTrue);
          expect(skip.overlaps(row), isFalse);
          expect(skip.overlaps(bubble), isFalse);
          expect(t.takeException(), isNull);
        });
      }
    }
  }
}
