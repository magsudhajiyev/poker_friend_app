import 'package:flutter/material.dart';

import '../models/game_types.dart';
import '../services/app_data_cache.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/live_session_logic.dart';
import '../services/live_session_notification_service.dart';
import '../services/tracked_session_service.dart';
import 'session_end_bankroll_sheet.dart';

/// Ends the running session from a screen that has a context (the Home bar's
/// "Still playing?" prompt, the one-running-session guard). A tracked session
/// goes through the NORMAL end-session sheet (cash-out, or prize and place),
/// so `session_results`, bankroll, play time and the Session History P/L are
/// written; play time and duration use [end]. Other sessions use the
/// live-session end path. False when the player cancelled the sheet (the
/// session keeps running) or the end failed.
class RunningSessionEnd {
  RunningSessionEnd._();

  /// Seam for tests: shows the end sheet; null = cancelled.
  static Future<Map<String, dynamic>?> Function(
    BuildContext context, {
    required GameType gameType,
    required double? profitLoss,
    required double totalBuyIn,
    required int durationMinutes,
    required DateTime endTime,
  }) showSheet = (context,
          {required gameType,
          required profitLoss,
          required totalBuyIn,
          required durationMinutes,
          required endTime}) =>
      SessionEndBankrollSheet.show(
        context: context,
        gameType: gameType,
        profitLoss: profitLoss,
        totalBuyIn: totalBuyIn,
        durationMinutes: durationMinutes,
        endTime: endTime,
      );

  /// Writes the end of an orphaned FULL session (its table cannot be
  /// reopened); a seam for tests. Result keys as the end sheet returns them.
  static Future<void> Function(LiveSessionRecord record, double buyIn,
      Map<String, dynamic> result, DateTime end) finishFull = _finishFull;

  static Future<void> _finishFull(LiveSessionRecord r, double buyIn,
      Map<String, dynamic> res, DateTime end) async {
    final cash = r.gameType != 'tournament';
    try {
      await FirebaseService.updateIndividualSession(
        sessionId: r.sessionId,
        currentStack: cash
            ? buyIn + ((res['profitLoss'] as num?)?.toDouble() ?? 0)
            : null,
        finishedPlace: res['finishedPlace'] as int?,
        fieldSize: res['fieldSize'] as int?,
        prizeWon: res['prizeWon'] as double?,
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}
    await LocalStorageService.endSession(r.sessionId, end.toIso8601String());
    try {
      final real = DateTime.now().difference(end) > const Duration(minutes: 1);
      await FirebaseService.endSession(r.sessionId, endTime: real ? end : null)
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
    AppDataCache.markHomeDirty();
    AppDataCache.markSessionsDirty();
    AppDataCache.markStatsDirty();
    await LiveSessionNotificationService.stop(r.sessionId);
  }

  /// A FULL session that can no longer be reopened (app restarted, or its
  /// table is gone) ends through the normal end sheet too: cash-out, or prize
  /// and place.
  static Future<bool> _endFull(
      BuildContext context, LiveSessionRecord record, DateTime end) async {
    final doc = await TrackedSessionService.loadDoc(record.sessionId);
    if (doc == null) {
      await LiveSessionNotificationService.stop(record.sessionId);
      return true;
    }
    if (!context.mounted) return false;
    final buyIn = ((doc['totalBuyIn'] ?? doc['buyInAmount']) as num?)
            ?.toDouble() ??
        0;
    final cash = record.gameType != 'tournament';
    double? lastStack;
    final h = doc['stackHistory'];
    if (h is List && h.isNotEmpty && h.last is Map) {
      lastStack = ((h.last as Map)['stackSize'] as num?)?.toDouble();
    }
    final endTime = end.isBefore(record.startTime) ? record.startTime : end;
    final res = await showSheet(
      context,
      gameType: cash ? GameType.cash : GameType.tournament,
      profitLoss: cash && lastStack != null ? lastStack - buyIn : null,
      totalBuyIn: buyIn,
      durationMinutes: endTime.difference(record.startTime).inMinutes,
      endTime: endTime,
    );
    if (res == null) return false;
    await finishFull(record, buyIn, res, endTime);
    return true;
  }

  static Future<bool> end(
      BuildContext context, LiveSessionRecord record, DateTime end) async {
    if (record.kind != LiveSessionRecord.kindTracked) {
      return _endFull(context, record, end);
    }
    final doc = await TrackedSessionService.loadDoc(record.sessionId);
    final session = doc == null
        ? null
        : TrackedSession.fromSession(record.sessionId, doc);
    if (doc == null || session == null) {
      // The session is gone: just clear the running record.
      await TrackedSessionService.liveStop(record.sessionId);
      return true;
    }
    if (!context.mounted) return false;
    final buyIn = (doc['totalBuyIn'] as num?)?.toDouble() ?? session.buyIn;
    final stack =
        (doc['currentStack'] as num?)?.toDouble() ?? session.startingStack;
    final cash = session.gameType == GameType.cash;
    var endTime = end.isBefore(session.startTime) ? session.startTime : end;
    final res = await showSheet(
      context,
      gameType: session.gameType,
      profitLoss: cash ? stack - buyIn : null,
      totalBuyIn: buyIn,
      durationMinutes: endTime.difference(session.startTime).inMinutes,
      endTime: endTime,
    );
    if (res == null) return false;
    await TrackedSessionService.finish(session,
        totalBuyIn: buyIn,
        result: TrackedSessionResult.fromSheet(res),
        endTime: endTime);
    return true;
  }
}
