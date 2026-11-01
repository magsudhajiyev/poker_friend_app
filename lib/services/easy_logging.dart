import 'package:flutter/foundation.dart';

import '../onboarding/onboarding_state.dart';
import 'feature_flag_service.dart';

/// Single gate for the "Easy Hand Logging" feature set.
///
/// Flag OFF (or an onboarding tour running) means the classic logging flow,
/// byte-for-byte. Screens snapshot [active] at a hand boundary, never per
/// frame: a mid-hand flag flip must not change the running hand.
class EasyLogging {
  EasyLogging._();

  /// Test hook: forces [flagOn] without touching Firebase.
  @visibleForTesting
  static bool? debugFlagOverride;

  /// Remote flag state for the current user (admin-only by default).
  static bool get flagOn {
    final o = debugFlagOverride;
    if (o != null) return o;
    try {
      return FeatureFlagService.isEnabled(FeatureFlagService.easyHandLogging);
    } catch (_) {
      return false; // Firebase not ready: stay on the classic flow.
    }
  }

  /// Flag on AND no in-app tour / tutorial running.
  static bool get active => flagOn && !_tourRunning;

  /// In-app tour only: the guided hand shows a non-interactive Flag chip and a
  /// "Flag a hand" coach mark when the flag is on for this user. Flag OFF =
  /// the tour is exactly the classic one (no chip, no step).
  static bool get tourFlagStep =>
      OnboardingState.isGuidedHandActive && flagOn;

  /// Test hook: forces the live-insights flag without touching Firebase.
  @visibleForTesting
  static bool? debugInsightsOverride;

  /// Payoff line + post-hand insight: needs easy logging AND its own flag.
  static bool get insightsActive {
    if (!active) return false;
    final o = debugInsightsOverride;
    if (o != null) return o;
    try {
      return FeatureFlagService.isEnabled(FeatureFlagService.liveInsights);
    } catch (_) {
      return false;
    }
  }

  /// Easy logging applies to own live sessions only: never dealer-assisted
  /// sessions and never tutorial sessions.
  static bool supportsSession({
    required bool isDealer,
    required bool isTutorial,
  }) =>
      active && !isDealer && !isTutorial;

  static bool get _tourRunning =>
      OnboardingState.isOnboardingActive ||
      OnboardingState.isGuidedHandActive ||
      OnboardingState.isGuidedSessionActive;
}
