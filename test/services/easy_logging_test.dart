import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/onboarding/onboarding_state.dart';
import 'package:poker_logger/services/easy_logging.dart';
import 'package:poker_logger/services/feature_flag_service.dart';

void main() {
  tearDown(() {
    EasyLogging.debugFlagOverride = null;
    EasyLogging.debugInsightsOverride = null;
    OnboardingState.isOnboardingActive = false;
    OnboardingState.currentPhase = 0;
  });

  test('flag registry: easy_hand_logging exists and defaults to adminOnly', () {
    final f = FeatureFlagService.all
        .firstWhere((f) => f.key == FeatureFlagService.easyHandLogging);
    expect(f.key, 'easy_hand_logging');
    expect(f.defaultMode, FlagMode.adminOnly);
    expect(FeatureFlagService.modeOf('easy_hand_logging'), FlagMode.adminOnly);
  });

  test('no Firebase / non-admin: flag reads as off, never throws', () {
    expect(EasyLogging.flagOn, isFalse);
    expect(EasyLogging.active, isFalse);
  });

  test('flag off -> inactive', () {
    EasyLogging.debugFlagOverride = false;
    expect(EasyLogging.active, isFalse);
  });

  test('flag on -> active', () {
    EasyLogging.debugFlagOverride = true;
    expect(EasyLogging.active, isTrue);
  });

  test('onboarding tour running -> inactive even with flag on', () {
    EasyLogging.debugFlagOverride = true;
    OnboardingState.isOnboardingActive = true;
    expect(EasyLogging.active, isFalse);
  });

  test('guided hand / guided session -> inactive even with flag on', () {
    EasyLogging.debugFlagOverride = true;
    OnboardingState.isOnboardingActive = true;
    OnboardingState.currentPhase = 4;
    expect(OnboardingState.isGuidedSessionActive, isTrue);
    expect(EasyLogging.active, isFalse);
  });

  group('tour Flag step gate', () {
    void guidedHand() {
      OnboardingState.start();
      OnboardingState.advanceTo(4);
      OnboardingState.guidedHandPhase = GuidedPhase.blindsPill;
    }

    tearDown(OnboardingState.cancel);

    test('flag on + guided hand -> Flag step shown', () {
      EasyLogging.debugFlagOverride = true;
      guidedHand();
      expect(EasyLogging.tourFlagStep, isTrue);
      expect(EasyLogging.active, isFalse,
          reason: 'easy logging itself stays off during the tour');
    });

    test('flag off + guided hand -> classic tour, no Flag step', () {
      EasyLogging.debugFlagOverride = false;
      guidedHand();
      expect(EasyLogging.tourFlagStep, isFalse);
    });

    test('flag on but no guided hand -> no Flag step', () {
      EasyLogging.debugFlagOverride = true;
      expect(EasyLogging.tourFlagStep, isFalse);
    });
  });

  test('supportsSession excludes dealer and tutorial sessions', () {
    EasyLogging.debugFlagOverride = true;
    expect(EasyLogging.supportsSession(isDealer: false, isTutorial: false),
        isTrue);
    expect(EasyLogging.supportsSession(isDealer: true, isTutorial: false),
        isFalse);
    expect(EasyLogging.supportsSession(isDealer: false, isTutorial: true),
        isFalse);
    EasyLogging.debugFlagOverride = false;
    expect(EasyLogging.supportsSession(isDealer: false, isTutorial: false),
        isFalse);
  });

  group('live_insights gate', () {
    test('registered, admin-only by default', () {
      final f = FeatureFlagService.all
          .firstWhere((f) => f.key == FeatureFlagService.liveInsights);
      expect(f.key, 'live_insights');
      expect(f.defaultMode, FlagMode.adminOnly);
    });

    test('needs BOTH easy logging and live_insights', () {
      EasyLogging.debugFlagOverride = true;
      EasyLogging.debugInsightsOverride = true;
      expect(EasyLogging.insightsActive, isTrue);

      EasyLogging.debugInsightsOverride = false;
      expect(EasyLogging.insightsActive, isFalse);

      EasyLogging.debugFlagOverride = false;
      EasyLogging.debugInsightsOverride = true;
      expect(EasyLogging.insightsActive, isFalse);
    });

    test('no Firebase: off, never throws', () {
      EasyLogging.debugFlagOverride = true;
      expect(EasyLogging.insightsActive, isFalse);
    });
  });
}
