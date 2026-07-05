import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// One remotely-toggleable feature.
class FeatureFlag {
  final String key;
  final String title;
  final String description;
  final bool defaultValue;
  const FeatureFlag(this.key, this.title, this.description,
      {required this.defaultValue});
}

/// Global feature flags, controlled by the super admin from the Profile
/// screen and applied to ALL users.
///
/// - Source of truth: Firestore `app_config/feature_flags` (one bool per
///   flag key). Firestore rules allow reads for signed-in users and writes
///   only for `isSuperAdmin()` (request.auth.token.email) — the client-side
///   email check here is UI convenience, not security.
/// - Offline: last-known values are cached in SharedPreferences so gating
///   works with zero network; unknown flags fall back to [FeatureFlag
///   .defaultValue] (which always matches current behavior, so a fresh
///   install without network changes nothing).
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

  static const List<FeatureFlag> all = [
    FeatureFlag(
      trainingDrills,
      'Training Drills',
      'Preflop spot trainer (GTO + exploit grading) on the logging screen.',
      defaultValue: true,
    ),
    FeatureFlag(
      aiHandAnalysis,
      'AI Hand Analysis',
      'Per-hand AI analysis button on hand details. Kill-switch for backend '
      'outages.',
      defaultValue: true,
    ),
  ];

  // ── State ─────────────────────────────────────────────────────────────

  static final Map<String, bool> _values = {};
  static const String _cachePrefix = 'feature_flag_';

  /// Bumps whenever flag values change; rebuild gated UI off this.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool get isSuperAdmin =>
      AuthService.currentUser?.email?.toLowerCase() ==
      superAdminEmail.toLowerCase();

  static bool isEnabled(String key) =>
      _values[key] ??
      all
          .firstWhere((f) => f.key == key,
              orElse: () =>
                  const FeatureFlag('', '', '', defaultValue: true))
          .defaultValue;

  // ── Lifecycle ─────────────────────────────────────────────────────────

  /// Loads the SharedPreferences cache, then subscribes to the Firestore
  /// doc. Safe to call before sign-in (reads attach once rules allow).
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final f in all) {
        final cached = prefs.getBool('$_cachePrefix${f.key}');
        if (cached != null) _values[f.key] = cached;
      }
      revision.value++;
    } catch (e) {
      debugPrint('FeatureFlagService cache load failed: $e');
    }
    try {
      FirebaseFirestore.instance
          .collection('app_config')
          .doc('feature_flags')
          .snapshots()
          .listen(_onRemote, onError: (e) {
        debugPrint('FeatureFlagService listener error: $e');
      });
    } catch (e) {
      debugPrint('FeatureFlagService subscribe failed: $e');
    }
  }

  static Future<void> _onRemote(DocumentSnapshot snap) async {
    final data = snap.data() as Map<String, dynamic>?;
    if (data == null) return;
    var changed = false;
    for (final f in all) {
      final v = data[f.key];
      if (v is bool && _values[f.key] != v) {
        _values[f.key] = v;
        changed = true;
      }
    }
    if (changed) {
      revision.value++;
      try {
        final prefs = await SharedPreferences.getInstance();
        for (final f in all) {
          final v = _values[f.key];
          if (v != null) await prefs.setBool('$_cachePrefix${f.key}', v);
        }
      } catch (_) {}
    }
  }

  /// Super-admin toggle. Firestore rules reject the write for anyone else.
  static Future<void> setFlag(String key, bool value) async {
    _values[key] = value; // optimistic — snapshot listener confirms
    revision.value++;
    await FirebaseFirestore.instance
        .collection('app_config')
        .doc('feature_flags')
        .set({key: value}, SetOptions(merge: true));
  }
}
