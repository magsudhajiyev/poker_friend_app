import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'logger_service.dart';
import 'send_time_logic.dart';

/// The user's personal send hour, from `users/{uid}.notif.activeHourUtc`
/// (written nightly by the web cron `cron-send-times`) converted to LOCAL
/// time with [SendTimeLogic.personalHour]. Reads are cached in memory for a
/// few hours; a failed or slow read (3s timeout) falls back to the cached
/// value, else the 19:00 default — callers never wait on it for UI.
class PersonalHourService {
  PersonalHourService._();

  static const Duration _ttl = Duration(hours: 6);
  static const Duration _timeout = Duration(seconds: 3);

  static String? _uid;
  static int? _activeHourUtc;
  static DateTime? _fetchedAt;

  static Future<int?> _activeHour() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return null;
    final fresh = _uid == uid &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < _ttl;
    if (fresh) return _activeHourUtc;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(_timeout);
      final notif = snap.data()?['notif'];
      final hour = notif is Map ? (notif['activeHourUtc'] as num?)?.toInt() : null;
      _uid = uid;
      _activeHourUtc = hour;
      _fetchedAt = DateTime.now();
      return hour;
    } catch (e) {
      LoggerService.warning('PersonalHour: read failed: $e');
      return _uid == uid ? _activeHourUtc : null;
    }
  }

  /// Local send hour (0–23), [leadHours] before the user's active hour.
  /// Falls back to [SendTimeLogic.fallbackReminderHour] minus the lead.
  static Future<int> localHour({int leadHours = 0}) async =>
      SendTimeLogic.personalHour(
        activeHourUtc: await _activeHour(),
        tzOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
        leadHours: leadHours,
      );
}
