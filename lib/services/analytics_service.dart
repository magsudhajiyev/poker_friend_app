import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../config/env_config.dart';
import 'logger_service.dart';

/// PostHog product analytics (ROADMAP Update 3 — minimal viable setup).
///
/// distinct_id is ALWAYS the Firebase uid: it matches RevenueCat's
/// customer_id, which is the join key against the PostHog Data Warehouse
/// tables (revenuecat_*, resend_*). Identity is wired to authStateChanges
/// so every sign-in path identifies and sign-out resets — call sites never
/// manage identity themselves.
///
/// Every method is fire-and-forget and swallows errors: analytics must
/// never break the app (same contract as FCM). All capture goes through
/// [capture] so the event vocabulary stays greppable — keep the event
/// names below in sync with the PostHog dashboard insights.
///
/// Event vocabulary (fire at the ONE canonical site each):
///   signup, tour_completed, hand_logged, session_ended, paywall_opened,
///   subscribed, ai_analysis_used, promo_redeemed
/// Leak Detector (flagged): leak_report_viewed, leak_tab_viewed,
///   leak_grid_opened, leak_review_queue_opened, leak_goal_set/_fixed/
///   _cleared, leak_shape_viewed/_grid_opened/_practice_tapped,
///   leak_session_chip_shown/_tapped
/// Daily Challenge (flagged): daily_challenge_opened,
///   daily_challenge_completed, daily_challenge_shared,
///   daily_challenge_range_viewed, daily_challenge_coach_picked
/// Plus SDK-automatic: Application Opened/Backgrounded (lifecycle — feeds
/// the retention chart).
class AnalyticsService {
  AnalyticsService._();

  static bool _enabled = false;
  static StreamSubscription<User?>? _authSub;
  static String? _identifiedUid;

  /// Initialize after EnvConfig.load(). No-op without a key, so dev
  /// environments and tests run silently without PostHog.
  static Future<void> init() async {
    final key = EnvConfig.posthogApiKey;
    if (key.isEmpty) {
      unawaited(LoggerService.debug('Analytics disabled (no POSTHOG_API_KEY)'));
      return;
    }
    try {
      final config = PostHogConfig(key)
        ..host = 'https://eu.i.posthog.com'
        // We use our own Firestore feature flags — skip the /flags request.
        ..preloadFeatureFlags = false
        ..sendFeatureFlagEvents = false;
      await Posthog().setup(config);
      _enabled = true;

      // Identity follows Firebase auth for every sign-in/out path.
      _authSub?.cancel();
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          _identify(user.uid);
        } else if (_identifiedUid != null) {
          _identifiedUid = null;
          _swallow(() => Posthog().reset());
        }
      });
    } catch (e) {
      unawaited(LoggerService.warning('Analytics init failed: $e'));
    }
  }

  static void _identify(String uid) {
    if (_identifiedUid == uid) return;
    _identifiedUid = uid;
    _swallow(() => Posthog().identify(userId: uid));
  }

  /// Capture a product event. [properties] values must be JSON-safe.
  static void capture(String event, [Map<String, Object>? properties]) {
    if (!_enabled) return;
    _swallow(() => Posthog().capture(eventName: event, properties: properties));
  }

  static void _swallow(Future<void> Function() call) {
    try {
      unawaited(call().catchError((_) {}));
    } catch (_) {
      // Analytics must never throw into app code.
    }
  }
}
