import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:posthog_flutter/posthog_flutter.dart';

import '../config/env_config.dart';
import 'auth_service.dart';
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
///   signup, tour_started, tour_completed, tour_skipped, hand_logged,
///   session_ended, paywall_opened, subscribed, ai_analysis_used,
///   promo_redeemed
/// Onboarding funnel: tour_started (OnboardingState.start(), real runs only,
///   never replay) -> tour_completed | tour_skipped{phase} (phase = tour
///   phase number, or `4_<GuidedPhase>` inside the guided hand; both skip
///   paths, never replay). paywall_opened fires ONCE per PaywallScreen mount
///   (initState) with {feature?, preselected_tier?, launch_promo}; feature is
///   the caller's featureName or a source label: post_tour, tour_skipped,
///   hard_gate, profile_promo, settings, notification, drawer.
/// Leak Detector (flagged): leak_report_viewed, leak_tab_viewed,
///   leak_grid_opened, leak_review_queue_opened, leak_goal_set/_fixed/
///   _cleared, leak_shape_viewed/_grid_opened/_practice_tapped,
///   leak_session_chip_shown/_tapped
/// Daily Challenge (flagged): daily_challenge_opened,
///   daily_challenge_completed, daily_challenge_shared,
///   daily_challenge_range_viewed, daily_challenge_coach_picked,
///   daily_challenge_leaderboard_submitted
/// Engagement notifications (flagged): notif_scheduled, notif_opened,
///   notif_converted (play within 2h of the push — the reward signal).
///   Paid nudges (flag `paid_nudges`) reuse these with type trial_recap /
///   missed_day / paywall_return; plus offers_consent{granted, source}
///   (source = prompt|settings, fired only in setOffers) and paywall_opened
///   {feature: paywall_return_push} when a paywall-return push is tapped
///   Spot quiz push (type spot_quiz) adds ONE event: spot_quiz_answered
///   {action} — a notification button was tapped (fired in
///   PaidNudgeService.open; a body tap fires only notif_opened)
/// Easy Hand Logging (flagged `easy_hand_logging`): fold_tick,
///   hand_flagged{tags}, flag_completed{lag_min},
///   hand_logging_abandoned{street}. Extra props on existing events:
///   hand_logged{completeness, time_to_log_ms, taps, street_reached, mode}
///   (mode = live|fold_tick|flag) and
///   session_ended{hands_logged, est_dealt, coverage, flags_open}.
///   Helpers live in hand_log_telemetry.dart / hand_coverage.dart.
/// Single-hand logging (flagged `single_hand`): single_hand_started{new_group},
///   single_hand_abandoned{street}, single_hand_post_action{action}
///   (action = view|log_another|done|star|note|tag). hand_logged carries
///   mode 'single' (plus group_hand_number) for these hands.
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
          _identify(user);
        } else if (_identifiedUid != null) {
          _identifiedUid = null;
          _swallow(() => Posthog().reset());
        }
      });
    } catch (e) {
      unawaited(LoggerService.warning('Analytics init failed: $e'));
    }
  }

  /// Identify the person to PostHog, keyed by Firebase uid (the warehouse join
  /// key), AND attach human-readable person properties so the dashboard shows a
  /// name/email instead of the raw uid. `name` and `email` are the properties
  /// PostHog's person UI renders by default. A placeholder display name (empty,
  /// or a private-relay local part) is dropped so we never show a junk token.
  static void _identify(User user) {
    if (_identifiedUid == user.uid) return;
    _identifiedUid = user.uid;

    final email = user.email?.trim() ?? '';
    final name = user.displayName?.trim() ?? '';
    final nameIsReal = !AuthService.isPlaceholderNameFor(name, email);

    final props = <String, Object>{
      if (nameIsReal) 'name': name,
      if (email.isNotEmpty) 'email': email,
    };

    _swallow(() => Posthog().identify(
          userId: user.uid,
          // `userProperties` sets person properties on every identify (keeps
          // name/email fresh if the user renames). Pass null when we have
          // nothing real to set so we don't overwrite with blanks.
          userProperties: props.isEmpty ? null : props,
        ));
  }

  /// Re-send person properties for the signed-in user — call after a rename or
  /// once a just-signed-up user has set their username, so PostHog picks up the
  /// real name without waiting for the next sign-in. No-op if nothing changed.
  static void refreshIdentity() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Force a re-identify even if the uid is unchanged (name may have changed).
    _identifiedUid = null;
    _identify(user);
  }

  /// Test seam: receives every captured event, even with analytics disabled.
  @visibleForTesting
  static void Function(String event, Map<String, Object>? props)? debugSink;

  /// Capture a product event. [properties] values must be JSON-safe.
  static void capture(String event, [Map<String, Object>? properties]) {
    debugSink?.call(event, properties);
    if (!_enabled) return;
    _swallow(() => Posthog().capture(eventName: event, properties: properties));
  }

  /// Onboarding: the guided tour really started (never a replay).
  static void tourStarted() => capture('tour_started');

  /// Onboarding: the tour was skipped at [phase] (never a replay).
  static void tourSkipped(String phase) =>
      capture('tour_skipped', {'phase': phase});

  /// A paywall was shown. [feature] = featureName or the source label.
  static void paywallOpened({
    String? feature,
    int? preselectedTier,
    bool launchPromo = false,
  }) =>
      capture('paywall_opened', {
        if (feature != null) 'feature': feature,
        if (preselectedTier != null) 'preselected_tier': preselectedTier,
        'launch_promo': launchPromo,
      });

  /// Single-hand logging: the setup sheet's "Start hand" was tapped.
  static void singleHandStarted({required bool newGroup}) =>
      capture('single_hand_started', {'new_group': newGroup});

  /// Single-hand logging: the table was left with actions logged but no save.
  static void singleHandAbandoned({String? street}) =>
      capture('single_hand_abandoned', {if (street != null) 'street': street});

  /// Single-hand logging: what the player did on the result sheet.
  static void singleHandPostAction(String action) =>
      capture('single_hand_post_action', {'action': action});

  static void _swallow(Future<void> Function() call) {
    try {
      unawaited(call().catchError((_) {}));
    } catch (_) {
      // Analytics must never throw into app code.
    }
  }
}
