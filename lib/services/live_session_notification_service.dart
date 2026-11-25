import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design_system/constants/colors.dart';
import '../widgets/live_session_bar.dart';
import 'app_data_cache.dart';
import '../utils/running_session_label.dart';
import 'app_l10n_lookup.dart';
import 'auth_service.dart';
import 'live_session_logic.dart';
import 'local_storage_service.dart';
import 'logger_service.dart';
import 'notification_service.dart';

/// Extension points other session code plugs into. Each returns true when it
/// handled the request; a null/false result falls back to the defaults in
/// [LiveSessionNotificationService].
class LiveSessionHooks {
  LiveSessionHooks._();

  /// "Open session" / notification body / Home "Resume" → the session hub.
  static Future<bool> Function(NavigatorState nav, LiveSessionRecord r)?
      openSession;

  /// "Log a hand" action → the single-hand flow for that session. When not
  /// set, [openSession] is used (the session hub).
  static Future<bool> Function(NavigatorState nav, LiveSessionRecord r)?
      logHand;

  /// End a running session at [endTime] through the owner's normal end path
  /// (session_results, stats). When not set, [defaultEnd] only stamps the end
  /// time on the session docs.
  static Future<bool> Function(LiveSessionRecord r, DateTime endTime)?
      endSession;
}

/// Android ongoing notification + persisted "running session" record
/// (decisions D25–D27 in docs/features/single-hand-setup-v2.md).
///
/// No background service: the record is the only source of truth after a
/// restart, and the notification's elapsed time is the system chronometer
/// counting from the start time. Every method here is best-effort and never
/// throws — a failure must not touch the session itself.
class LiveSessionNotificationService {
  LiveSessionNotificationService._();

  static const _prefsKey = 'live_session_record';
  static const _channelId = 'live_session';

  /// The running session (null = none). Home's bar listens to this.
  static final ValueNotifier<LiveSessionRecord?> running = ValueNotifier(null);

  /// Sessions started in this process. A `full` session started here still has
  /// its manager/hub alive; after a restart it is an orphan with no hub.
  static final Set<String> _startedThisProcess = {};

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// A session started (or resumed). Persists the record and posts the
  /// notification. [kind]: `'full'` for PokerSessionManager sessions.
  static Future<void> start({
    required String sessionId,
    required String name,
    required String gameType,
    required DateTime startTime,
    String kind = LiveSessionRecord.kindTracked,
  }) async {
    try {
      final previous = await current();
      if (previous != null && previous.sessionId != sessionId) {
        // One running session at a time: never silently replace another one.
        // (A record whose session already ended is stale and is replaced.)
        if (!await isStale(previous)) {
          unawaited(LoggerService.error(
              'LiveSession start refused: "${previous.name}" '
              '(${previous.sessionId}) is still running, not starting '
              '$sessionId',
              StateError('session already running'),
              StackTrace.current));
          return;
        }
        await _cancel(previous.sessionId);
      }
      final record = LiveSessionRecord(
        sessionId: sessionId,
        name: name,
        gameType: gameType,
        startTime: startTime,
        kind: kind,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, record.encode());
      _startedThisProcess.add(sessionId);
      running.value = record;
      await _post(record);
    } catch (e) {
      unawaited(LoggerService.warning('LiveSession start failed: $e'));
    }
  }

  /// The record's session ended or is gone from the local data (seam for tests).
  @visibleForTesting
  static Future<bool> Function(LiveSessionRecord r) isStale = (r) async {
    try {
      final s = await LocalStorageService.getSession(r.sessionId);
      return s == null || s['endTime'] != null;
    } catch (_) {
      return false;
    }
  };

  /// Ids of sessions stopped in this process: the data reconcile never brings
  /// them back, even if their `endTime` write has not landed yet.
  static final Set<String> stoppedIds = {};

  /// The session ended or was discarded.
  static Future<void> stop(String sessionId) async {
    try {
      _startedThisProcess.remove(sessionId);
      stoppedIds.add(sessionId);
      await _cancel(sessionId);
      final record = await current();
      if (record != null && record.sessionId != sessionId) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      running.value = null;
    } catch (e) {
      unawaited(LoggerService.warning('LiveSession stop failed: $e'));
    }
  }

  /// App launch: re-post the notification for a session that is still running
  /// (some Android skins remove ongoing notifications on swipe-away).
  static Future<void> restoreOnLaunch() async {
    try {
      final record = await current();
      running.value = record;
      if (record != null) await _post(record);
    } catch (e) {
      unawaited(LoggerService.warning('LiveSession restore failed: $e'));
    }
  }

  /// The persisted running session, if any.
  static Future<LiveSessionRecord?> current() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return LiveSessionRecord.decode(prefs.getString(_prefsKey));
    } catch (_) {
      return null;
    }
  }

  // ── Notification ──────────────────────────────────────────────────────

  /// Pure, so tests can pin the contract: ongoing, silent, system chronometer
  /// from the start time, no money anywhere.
  @visibleForTesting
  static AndroidNotificationDetails androidDetails({
    required DateTime startTime,
    required String logHandLabel,
    required String openLabel,
  }) {
    return AndroidNotificationDetails(
      _channelId,
      'Running session',
      channelDescription: 'Shows the session you are playing right now',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      usesChronometer: true,
      when: startTime.millisecondsSinceEpoch,
      icon: '@drawable/ic_notification',
      color: AppColors.accentPrimary,
      category: AndroidNotificationCategory.progress,
      actions: [
        AndroidNotificationAction(LiveSessionLogic.actionIdLogHand,
            logHandLabel,
            showsUserInterface: true, cancelNotification: false),
        AndroidNotificationAction(LiveSessionLogic.actionIdOpen, openLabel,
            showsUserInterface: true, cancelNotification: false),
      ],
    );
  }

  static Future<void> _post(LiveSessionRecord r) async {
    if (!_isAndroid) return;
    try {
      await NotificationService.initialize();
      final l10n = AppL10nLookup.current();
      final details = androidDetails(
        startTime: r.startTime,
        logHandLabel: l10n.liveSessionActionLogHand,
        openLabel: l10n.liveSessionActionOpen,
      );
      final title = runningSessionLabel(l10n, r);
      final body = r.gameType == 'tournament'
          ? l10n.homeTournament
          : l10n.homeCashGame;
      await NotificationService.plugin
          .show(
            LiveSessionLogic.notificationId(r.sessionId),
            title,
            body,
            NotificationDetails(android: details),
            payload: LiveSessionLogic.payload(
                LiveSessionAction.open, r.sessionId),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      unawaited(LoggerService.warning('LiveSession post failed: $e'));
    }
  }

  static Future<void> _cancel(String sessionId) async {
    if (!_isAndroid) return;
    try {
      await NotificationService.plugin
          .cancel(LiveSessionLogic.notificationId(sessionId))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      unawaited(LoggerService.warning('LiveSession cancel failed: $e'));
    }
  }

  // ── Tap routing ───────────────────────────────────────────────────────

  static bool _routing = false;

  /// Called by NotificationService for a `live_session:` payload (tap, button
  /// or cold-start launch). Waits for the navigator + a signed-in user.
  static Future<void> onTapped(String? payload, String? actionId) async {
    final tap = LiveSessionLogic.resolveTap(payload, actionId);
    if (tap == null || _routing) return;
    _routing = true;
    try {
      NavigatorState? nav;
      for (var i = 0; i < 30; i++) {
        nav = NotificationService.navigatorKey?.currentState;
        if (nav != null && AuthService.currentUser != null) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }
      nav = NotificationService.navigatorKey?.currentState;
      if (nav == null || AuthService.currentUser == null) return;
      await Future.delayed(const Duration(milliseconds: 800));
      final record = await current();
      if (record == null || record.sessionId != tap.sessionId) return;
      await openRecord(nav, record,
          action: tap.action, promptIfUnhandled: true);
    } catch (e) {
      unawaited(LoggerService.warning('LiveSession tap failed: $e'));
    } finally {
      _routing = false;
    }
  }

  /// Open [record] through the hooks. Returns true when something handled it.
  /// A `full` session from a previous process has no hub to reopen, so when no
  /// hook handles it the caller may show the end prompt instead.
  static Future<bool> openRecord(
    NavigatorState nav,
    LiveSessionRecord record, {
    LiveSessionAction action = LiveSessionAction.open,
    bool promptIfUnhandled = false,
  }) async {
    var handled = false;
    try {
      final hook = action == LiveSessionAction.logHand
          ? (LiveSessionHooks.logHand ?? LiveSessionHooks.openSession)
          : LiveSessionHooks.openSession;
      handled = hook != null && await hook(nav, record);
    } catch (e) {
      unawaited(LoggerService.warning('LiveSession hook failed: $e'));
    }
    final aliveHere = _startedThisProcess.contains(record.sessionId);
    if (!handled && promptIfUnhandled && !aliveHere) {
      final ctx = nav.context;
      if (ctx.mounted) await promptEnd(ctx, record);
    }
    return handled;
  }

  // ── Ending ────────────────────────────────────────────────────────────

  /// End [record] at [endTime] (clamped into [start, now]). Uses the owner's
  /// hook when set, else [defaultEnd]. Clears the record on success.
  static Future<bool> endAt(LiveSessionRecord record, DateTime endTime) async {
    try {
      final now = DateTime.now();
      var end = endTime;
      if (end.isBefore(record.startTime)) end = record.startTime;
      if (end.isAfter(now)) end = now;
      final hook = LiveSessionHooks.endSession;
      final done = hook != null
          ? await hook(record, end)
          : await defaultEnd(record, end);
      if (done) await stop(record.sessionId);
      return done;
    } catch (e) {
      unawaited(LoggerService.warning('LiveSession end failed: $e'));
      return false;
    }
  }

  /// Only stamps `endTime` on the local + cloud session docs. It does NOT run
  /// the normal end flow (bankroll sheet, session_results, play-time stats) —
  /// owners of a session type install [LiveSessionHooks.endSession] for that.
  static Future<bool> defaultEnd(LiveSessionRecord r, DateTime end) async {
    await LocalStorageService.endSession(r.sessionId, end.toIso8601String());
    final uid = AuthService.userId;
    if (uid != null && !r.sessionId.startsWith('offline_')) {
      try {
        await FirebaseFirestore.instance
            .collection('poker_sessions')
            .doc(r.sessionId)
            .update({'endTime': Timestamp.fromDate(end)}).timeout(
                const Duration(seconds: 8));
      } catch (e) {
        unawaited(LoggerService.warning('LiveSession cloud end failed: $e'));
      }
    }
    AppDataCache.markHomeDirty();
    AppDataCache.markSessionsDirty();
    AppDataCache.markStatsDirty();
    return true;
  }

  /// The "Still playing?" prompt (D27 rule 1).
  static Future<void> promptEnd(
          BuildContext context, LiveSessionRecord record) =>
      showLiveSessionPrompt(context, record);
}
