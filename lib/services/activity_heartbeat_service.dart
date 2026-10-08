import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logger_service.dart';

/// DAU heartbeat: stamps `users/{uid}.lastActiveAt` (server timestamp) on
/// sign-in and app foreground, throttled to once per hour.
///
/// Wire contract with the admin dashboard (its daily cron counts users
/// with lastActiveAt in the past day and snapshots to `daily_stats`):
///   users/{uid}.lastActiveAt — Firestore server timestamp, written on
///   foreground at most once per hour.
///
/// Same reliability contract as FCM/analytics: every call is
/// fire-and-forget and must never break the app. Firestore rules already
/// permit owner writes to non-tier fields on users/{uid} — no rules
/// change needed.
class ActivityHeartbeatService {
  ActivityHeartbeatService._();

  static const _prefsKey = 'last_active_heartbeat_ms';
  static const throttle = Duration(hours: 1);

  static DateTime? _lastWrite;
  static StreamSubscription<User?>? _authSub;

  /// Call once at startup (alongside the other service inits). Stamps on
  /// every sign-in — which includes the persisted-session restore on cold
  /// start — so launches count without any extra call site.
  static void init() {
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) recordActive();
    });
  }

  /// Pure throttle decision — unit-tested.
  static bool shouldWrite(DateTime? lastWrite, DateTime now) =>
      lastWrite == null || now.difference(lastWrite) >= throttle;

  /// Stamp activity if the throttle window has passed. Safe to call
  /// opportunistically (resume, sign-in); no-op when signed out.
  static Future<void> recordActive() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final now = DateTime.now();
      // Cheap in-memory gate first; fall back to the persisted stamp so
      // cold starts within the hour don't rewrite.
      if (!shouldWrite(_lastWrite, now)) return;
      final prefs = await SharedPreferences.getInstance();
      final storedMs = prefs.getInt(_prefsKey);
      final stored = storedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(storedMs);
      if (!shouldWrite(stored, now)) {
        _lastWrite = stored;
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'lastActiveAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
      _lastWrite = now;
      await prefs.setInt(_prefsKey, now.millisecondsSinceEpoch);
    } catch (e) {
      // Never let the heartbeat interfere with the app.
      unawaited(LoggerService.debug('Activity heartbeat failed: $e'));
    }
  }
}
