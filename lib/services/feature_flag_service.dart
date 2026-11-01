import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Rollout state of one feature.
enum FlagMode {
  /// Visible to everyone.
  on,

  /// Visible only to the super admin (preview mode).
  adminOnly,

  /// Hidden for everyone, super admin included (full kill-switch).
  off,
}

/// One remotely-toggleable feature.
class FeatureFlag {
  final String key;
  final String title;
  final String description;
  final FlagMode defaultMode;
  const FeatureFlag(this.key, this.title, this.description,
      {required this.defaultMode});
}

/// Global feature flags, controlled by the super admin from the Profile
/// screen and applied to ALL users.
///
/// - Source of truth: Firestore `app_config/feature_flags` — one value per
///   flag key: 'on' | 'admin_only' | 'off' (legacy bools from the first
///   version are still accepted: true='on', false='off'). Firestore rules
///   allow reads for signed-in users and writes only for `isSuperAdmin()`
///   (request.auth.token.email) — the client-side email check here is UI
///   convenience, not security.
/// - Offline: last-known modes are cached in SharedPreferences so gating
///   works with zero network; unknown flags fall back to
///   [FeatureFlag.defaultMode].
/// - UI: listen via [revision] (ValueListenableBuilder) — it bumps whenever
///   flag values change.
class FeatureFlagService {
  FeatureFlagService._();

  static const String superAdminEmail = 'magsud94@gmail.com';

  // ── Flag registry ─────────────────────────────────────────────────────
  // To gate a new feature: add a FeatureFlag here, then wrap its entry
  // point in `if (FeatureFlagService.isEnabled(FeatureFlagService.<key>))`
  // inside a ValueListenableBuilder on [revision].

  static const String trainingDrills = 'training_drills';
  static const String aiHandAnalysis = 'ai_hand_analysis';
  static const String leakDetector = 'leak_detector';
  static const String dailyChallenge = 'daily_challenge';
  static const String engagementNotifications = 'engagement_notifications';
  static const String hardPaywall = 'hard_paywall';
  static const String easyHandLogging = 'easy_hand_logging';
  static const String liveInsights = 'live_insights';

  static const List<FeatureFlag> all = [
    FeatureFlag(
      trainingDrills,
      'Training Drills',
      'Preflop spot trainer (GTO + exploit grading) on the logging screen.',
      defaultMode: FlagMode.on,
    ),
    FeatureFlag(
      aiHandAnalysis,
      'AI Hand Analysis',
      'Per-hand AI analysis button on hand details. Kill-switch for backend '
      'outages.',
      defaultMode: FlagMode.on,
    ),
    FeatureFlag(
      leakDetector,
      'Leak Detector',
      'Frequency-leak report (overfolding vs river bets, fold-to-3-bet, '
      'BB defense...) in the navigation drawer. Phase 1 experiment.',
      defaultMode: FlagMode.adminOnly,
    ),
    FeatureFlag(
      dailyChallenge,
      'Daily Challenge',
      'Date-seeded daily decision spots graded live by the coach, with '
      'streaks. Home screen card. Phase 1 experiment.',
      defaultMode: FlagMode.adminOnly,
    ),
    FeatureFlag(
      engagementNotifications,
      'Engagement Notifications',
      'Coach-voiced streak-saver / leaderboard / comeback pushes + the '
      'Settings notification preferences. Dark-launch switch for the '
      'scheduler.',
      defaultMode: FlagMode.adminOnly,
    ),
    FeatureFlag(
      hardPaywall,
      'Hard Paywall',
      'Removes the free tier: a signed-in, onboarded user without an active '
      'subscription is sent to a non-dismissible paywall (start the trial to '
      'use the app). OFF by default — enable to switch the app to the hard '
      'paywall.',
      defaultMode: FlagMode.off,
    ),
    FeatureFlag(
      easyHandLogging,
      'Easy Hand Logging',
      'Fold ticker, flag-now-finish-later hands, '
      'and learned raise sizes on the live hand logger. OFF = the classic logging flow.',
      defaultMode: FlagMode.adminOnly,
    ),
    FeatureFlag(
      liveInsights,
      'Live Insights',
      'Payoff line under the table (how a seat played tonight) and the '
      'one-line insight after each hand. Needs Easy Hand Logging too.',
      defaultMode: FlagMode.adminOnly,
    ),
  ];

  // ── State ─────────────────────────────────────────────────────────────

  static final Map<String, FlagMode> _modes = {};
  static const String _cachePrefix = 'feature_flag_mode_';

  /// Bumps whenever flag values change; rebuild gated UI off this.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool get isSuperAdmin =>
      AuthService.currentUser?.email?.toLowerCase() ==
      superAdminEmail.toLowerCase();

  static FlagMode modeOf(String key) =>
      _modes[key] ??
      all
          .firstWhere((f) => f.key == key,
              orElse: () => const FeatureFlag('', '', '',
                  defaultMode: FlagMode.on))
          .defaultMode;

  /// Whether the feature is visible for the CURRENT user.
  static bool isEnabled(String key) => switch (modeOf(key)) {
        FlagMode.on => true,
        FlagMode.off => false,
        FlagMode.adminOnly => isSuperAdmin,
      };

  static String _encode(FlagMode m) => switch (m) {
        FlagMode.on => 'on',
        FlagMode.adminOnly => 'admin_only',
        FlagMode.off => 'off',
      };

  static FlagMode? _decode(dynamic v) => switch (v) {
        'on' => FlagMode.on,
        'admin_only' => FlagMode.adminOnly,
        'off' => FlagMode.off,
        true => FlagMode.on, // legacy bool format
        false => FlagMode.off,
        _ => null,
      };

  // ── Lifecycle ─────────────────────────────────────────────────────────

  static bool _initialized = false;
  static StreamSubscription<DocumentSnapshot>? _flagSub;

  /// Loads the SharedPreferences cache, then (re)subscribes to the Firestore
  /// doc whenever a user signs in. The rules require auth, so a listener
  /// attached before sign-in is killed by permission-denied and would never
  /// recover; we attach per auth state instead. Idempotent.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final f in all) {
        final m = _decode(prefs.getString('$_cachePrefix${f.key}'));
        if (m != null) _modes[f.key] = m;
      }
      revision.value++;
    } catch (e) {
      debugPrint('FeatureFlagService cache load failed: $e');
    }
    try {
      AuthService.authStateChanges.listen(_onAuthChanged);
    } catch (e) {
      debugPrint('FeatureFlagService auth subscribe failed: $e');
    }
  }

  static void _onAuthChanged(User? user) {
    _flagSub?.cancel();
    _flagSub = null;
    if (user == null) return; // keep current modes + cache
    try {
      _flagSub = FirebaseFirestore.instance
          .collection('app_config')
          .doc('feature_flags')
          .snapshots()
          .listen(_onRemote, onError: (e) {
        debugPrint('FeatureFlagService listener error: $e');
        _flagSub?.cancel(); // errored listeners are dead; next auth re-attaches
        _flagSub = null;
      });
    } catch (e) {
      debugPrint('FeatureFlagService subscribe failed: $e');
    }
  }

  static Future<void> _onRemote(DocumentSnapshot snap) =>
      applyRemote(snap.data() as Map<String, dynamic>?);

  /// Applies a remote flag map (bumps [revision], writes the cache).
  @visibleForTesting
  static Future<void> applyRemote(Map<String, dynamic>? data) async {
    if (data == null) return;
    var changed = false;
    for (final f in all) {
      final m = _decode(data[f.key]);
      if (m != null && _modes[f.key] != m) {
        _modes[f.key] = m;
        changed = true;
      }
    }
    if (changed) {
      revision.value++;
      try {
        final prefs = await SharedPreferences.getInstance();
        for (final f in all) {
          final m = _modes[f.key];
          if (m != null) {
            await prefs.setString('$_cachePrefix${f.key}', _encode(m));
          }
        }
      } catch (_) {}
    }
  }

  /// Super-admin toggle. Firestore rules reject the write for anyone else.
  static Future<void> setMode(String key, FlagMode mode) async {
    _modes[key] = mode; // optimistic — snapshot listener confirms
    revision.value++;
    await FirebaseFirestore.instance
        .collection('app_config')
        .doc('feature_flags')
        .set({key: _encode(mode)}, SetOptions(merge: true));
  }
}
