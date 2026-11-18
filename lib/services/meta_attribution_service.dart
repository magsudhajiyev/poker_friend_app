import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/widgets.dart';

import '../onboarding/onboarding_prefs.dart';
import '../onboarding/onboarding_state.dart';
import 'auth_service.dart';
import 'logger_service.dart';

/// Which Meta standard event a successful subscription purchase maps to.
enum MetaPurchaseKind { startTrial, purchase }

/// A purchase that begins a free trial is `fb_mobile_start_trial` (nothing was
/// charged yet); any other purchase is `fb_mobile_purchase`. Never both.
MetaPurchaseKind metaPurchaseKind({required bool inTrial}) =>
    inTrial ? MetaPurchaseKind.startTrial : MetaPurchaseKind.purchase;

/// Firebase provider id -> Meta registration method. Null = do not log
/// (guest accounts are not a completed registration).
String? metaRegistrationMethod(String providerId) {
  switch (providerId) {
    case 'password':
      return 'email';
    case 'google.com':
      return 'google';
    case 'apple.com':
      return 'apple';
    default:
      return null;
  }
}

/// Meta (Facebook) SDK: install attribution + app events ONLY (no login).
///
/// Static, fire-and-forget, never throws (same contract as AnalyticsService).
/// Events carry no personal data (no email, name, uid or username).
///
/// `fb_mobile_activate_app` is NOT logged here: with auto-logging on, the
/// native SDKs log it themselves on every foreground (and the install event
/// on first launch). A manual call would double count.
class MetaAttributionService {
  MetaAttributionService._();

  static final FacebookAppEvents _fb = FacebookAppEvents();
  static bool _trackingFlowStarted = false;

  /// Call once at startup. Does not block and does not prompt.
  static void init() {
    unawaited(_safe('setAutoLogAppEventsEnabled',
        () => _fb.setAutoLogAppEventsEnabled(true)));
  }

  /// iOS only: ask for App Tracking Transparency ONCE (only while the status
  /// is notDetermined) at a moment that cannot collide with the tour, the
  /// post-tour wrap-up/paywall or the sign-in flow.
  ///
  /// Safe moment = first frame rendered, user signed in (sign-in sheets are
  /// gone), the in-app tour is not running, and no post-tour step (paywall,
  /// bankroll tip, wrap-up, signup) is pending. Otherwise it re-checks every
  /// few seconds (bounded), so a first-run user gets the prompt right after
  /// the tour/paywall chain instead of on top of it.
  static void requestTrackingWhenSafe() {
    if (!Platform.isIOS || _trackingFlowStarted) return;
    _trackingFlowStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_trackingLoop());
    });
  }

  static Future<void> _trackingLoop() async {
    try {
      await Future<void>.delayed(const Duration(seconds: 4));
      for (var i = 0; i < 120; i++) {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status != TrackingStatus.notDetermined) {
          await _applyTracking(status);
          return;
        }
        if (await _isSafeMoment() && await _isAppActive()) {
          final result =
              await AppTrackingTransparency.requestTrackingAuthorization();
          if (result != TrackingStatus.notDetermined) {
            await _applyTracking(result);
            return;
          }
          // Prompt was suppressed (e.g. another system alert) — try again.
        }
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    } catch (e) {
      unawaited(LoggerService.debug('Meta ATT flow skipped: $e'));
    }
  }

  static Future<bool> _isAppActive() async =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  static Future<bool> _isSafeMoment() async {
    if (!AuthService.isSignedIn) return false;
    if (OnboardingState.isOnboardingActive) return false;
    final pending = await Future.wait([
      OnboardingPrefs.isPostTourPaywallPending(),
      OnboardingPrefs.isPostTourSignupRequired(),
      OnboardingPrefs.isBankrollTourPending(),
      OnboardingPrefs.isPostTourWrapUpPending(),
      OnboardingPrefs.isPromoCongratsPending(),
    ]);
    return !pending.any((p) => p);
  }

  static Future<void> _applyTracking(TrackingStatus status) async {
    // ignore: deprecated_member_use
    await _safe('setAdvertiserTracking', () => _fb.setAdvertiserTracking(
        enabled: status == TrackingStatus.authorized));
  }

  /// New account only. [providerId] is the Firebase provider id.
  static void logRegistration(String providerId) {
    final method = metaRegistrationMethod(providerId);
    if (method == null) return;
    unawaited(_safe('registration',
        () => _fb.logCompletedRegistration(registrationMethod: method)));
  }

  /// Successful purchase (never restore). A purchase that starts an intro
  /// free trial logs start_trial (value 0) INSTEAD of purchase.
  static void logSubscription({
    required double price,
    required String currency,
    required bool inTrial,
    required String packageId,
  }) {
    if (currency.isEmpty) return;
    switch (metaPurchaseKind(inTrial: inTrial)) {
      case MetaPurchaseKind.startTrial:
        unawaited(_safe('start_trial', () => _fb.logStartTrial(
            price: 0, currency: currency, orderId: packageId)));
      case MetaPurchaseKind.purchase:
        unawaited(_safe('purchase',
            () => _fb.logPurchase(amount: price, currency: currency)));
    }
  }

  @visibleForTesting
  static void resetForTest() => _trackingFlowStarted = false;

  static Future<void> _safe(String what, Future<void> Function() call) async {
    try {
      await call();
    } catch (e) {
      unawaited(LoggerService.debug('Meta $what failed: $e'));
    }
  }
}
