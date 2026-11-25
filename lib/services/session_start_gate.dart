import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/single_hand_group.dart';
import '../models/tracked_session.dart';
import 'live_session_logic.dart';
import 'live_session_notification_service.dart';
import 'local_storage_service.dart';
import 'logger_service.dart';
import 'session_navigation.dart';

/// Thrown when a session is started while another one runs.
class SessionAlreadyRunning implements Exception {
  final LiveSessionRecord running;
  const SessionAlreadyRunning(this.running);
  @override
  String toString() => 'SessionAlreadyRunning(${running.name})';
}

/// The ONE place that knows whether a session is running, and the one rule
/// every session creator goes through: only one session runs at a time.
///
/// The source of truth is the DATA (a session with no `endTime`), not the
/// SharedPreferences record the notification and the Home bar use: the record
/// can be missing (app killed, a full session whose table was never opened) or
/// stale. [findRunning] reconciles both.
class SessionStartGate {
  SessionStartGate._();

  /// A full session with no end time older than this is an abandoned old
  /// session, not a running one (it never blocks a new session).
  static const Duration fullSessionWindow = Duration(hours: 24);

  /// Seams for tests.
  @visibleForTesting
  static Future<List<Map<String, dynamic>>> Function() localSessions =
      () => LocalStorageService.getUserSessions();
  static Future<Map<String, dynamic>?> Function(String id) localSession =
      LocalStorageService.getSession;
  static Future<LiveSessionRecord?> Function() currentRecord =
      LiveSessionNotificationService.current;
  static Future<void> Function(LiveSessionRecord r) rebuildRecord = (r) =>
      LiveSessionNotificationService.start(
        sessionId: r.sessionId,
        name: r.name,
        gameType: r.gameType,
        startTime: r.startTime,
        kind: r.kind,
      );
  static Future<void> Function(String id) dropRecord =
      LiveSessionNotificationService.stop;
  static DateTime Function() now = DateTime.now;

  /// Name and game type of the full session whose hub is open but whose table
  /// has not created the session yet (set by the full-session setup).
  static ({String name, String gameType})? pendingFull;

  /// Id of the synthetic record for a full session that has no data yet.
  static const String pendingFullId = 'pending-full';

  /// The running session, or null. Reconciles the record with the data:
  /// a stale record (its session ended) is dropped; a running session with no
  /// record gets its record rebuilt (so the Home bar can end it).
  static Future<LiveSessionRecord?> findRunning() async {
    try {
      var record = await currentRecord();
      if (record != null && await _hasEnded(record)) {
        await dropRecord(record.sessionId);
        record = null;
      }
      if (record != null) return record;
      final fromData = await _runningFromData();
      if (fromData != null) {
        await rebuildRecord(fromData);
        return fromData;
      }
      return _pendingFullRecord();
    } catch (e) {
      unawaited(LoggerService.warning('SessionStartGate.findRunning: $e'));
      return null;
    }
  }

  /// Rebuilds a missing record for a running session without asking (Home bar
  /// on open, so an orphaned session can be ended there).
  static Future<void> reconcile() async {
    await findRunning();
  }

  /// Throws [SessionAlreadyRunning] when a session runs. [ignorePending]: the
  /// caller IS the full session whose hub is open (its table starting).
  static Future<void> assertNoRunning({bool ignorePending = false}) async {
    final r = await findRunning();
    if (r == null) return;
    if (ignorePending && r.sessionId == pendingFullId) return;
    throw SessionAlreadyRunning(r);
  }

  static LiveSessionRecord? _pendingFullRecord() {
    if (!SessionNavigation.isOpen(SessionNavigation.fullHubKey)) return null;
    final p = pendingFull;
    return LiveSessionRecord(
      sessionId: pendingFullId,
      name: p?.name ?? '',
      gameType: p?.gameType ?? 'cash',
      startTime: now(),
      kind: LiveSessionRecord.kindFull,
    );
  }

  static DateTime? _time(Object? v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// The record points at a session that ended or no longer exists locally.
  static Future<bool> _hasEnded(LiveSessionRecord r) async {
    final s = await localSession(r.sessionId);
    if (s == null) return true;
    return s['endTime'] != null;
  }

  /// Newest session in the local data with no end time that really runs.
  static Future<LiveSessionRecord?> _runningFromData() async {
    final all = await localSessions();
    LiveSessionRecord? best;
    for (final s in all) {
      final id = '${s['id'] ?? ''}';
      if (id.isEmpty || s['endTime'] != null) continue;
      if (LiveSessionNotificationService.stoppedIds.contains(id)) continue;
      if (isHandGroupSession(s) || s['isTutorial'] == true) continue;
      final start = _time(s['startTime']);
      if (start == null) continue;
      final tracked = isTrackedSession(s);
      if (!tracked && now().difference(start) > fullSessionWindow) continue;
      if (best != null && !start.isAfter(best.startTime)) continue;
      best = LiveSessionRecord(
        sessionId: id,
        name: '${s['sessionName'] ?? ''}',
        gameType: s['gameType'] == 'tournament' ? 'tournament' : 'cash',
        startTime: start,
        kind: tracked
            ? LiveSessionRecord.kindTracked
            : LiveSessionRecord.kindFull,
      );
    }
    return best;
  }
}
