import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/game_types.dart';
import '../models/tracked_session.dart';
import 'app_data_cache.dart';
import 'auth_service.dart';
import 'firebase_service.dart';
import 'live_session_notification_service.dart';
import 'live_session_logic.dart';
import 'session_start_gate.dart';
import 'local_storage_service.dart';
import 'bankroll_service.dart';
import 'session_result_service.dart';
import 'logger_service.dart';

/// A running or finished "Track a session" session: a real session for money
/// and time that only holds single hands (docs/features/single-hand-setup-v2.md,
/// D17-D24). No seats, no blinds.
class TrackedSession {
  final String id;
  final String name;
  final GameType gameType;
  final double buyIn;

  /// Cash: the buy-in (money is the stack). Tournament: optional chips, 0 when
  /// the player did not enter any.
  final double startingStack;
  final DateTime startTime;

  const TrackedSession({
    required this.id,
    required this.name,
    required this.gameType,
    required this.buyIn,
    required this.startingStack,
    required this.startTime,
  });

  /// Reads a `poker_sessions` map (Firestore or SQLite). Null when it is not a
  /// tracked session or has no usable start time.
  static TrackedSession? fromSession(String id, Map<String, dynamic> m) {
    if (!isTrackedSession(m)) return null;
    final start = _time(m['startTime']);
    if (start == null) return null;
    final buyIn = ((m['buyInAmount'] ?? m['totalBuyIn']) as num?)?.toDouble();
    return TrackedSession(
      id: id,
      name: m['sessionName']?.toString() ?? '',
      gameType:
          m['gameType'] == 'tournament' ? GameType.tournament : GameType.cash,
      buyIn: buyIn ?? 0,
      startingStack: (m['startingStack'] as num?)?.toDouble() ?? 0,
      startTime: start,
    );
  }

  static DateTime? _time(Object? v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is Timestamp) return v.toDate();
    return null;
  }
}

/// What the end-session sheet reports (`SessionEndBankrollSheet`): profit or
/// loss, and for tournaments the finish.
class TrackedSessionResult {
  final double profitLoss;
  final int? finishedPlace;
  final int? fieldSize;
  final double? prizeWon;

  const TrackedSessionResult({
    required this.profitLoss,
    this.finishedPlace,
    this.fieldSize,
    this.prizeWon,
  });

  factory TrackedSessionResult.fromSheet(Map<String, dynamic> m) =>
      TrackedSessionResult(
        profitLoss: (m['profitLoss'] as num?)?.toDouble() ?? 0,
        finishedPlace: m['finishedPlace'] as int?,
        fieldSize: m['fieldSize'] as int?,
        prizeWon: (m['prizeWon'] as num?)?.toDouble(),
      );
}

/// Storage the service needs. The real one writes Firestore + SQLite; tests
/// inject a fake.
abstract class TrackedSessionBackend {
  Future<void> create(TrackedSession s);

  /// The stored session doc (cloud first, SQLite fallback), or null.
  Future<Map<String, dynamic>?> load(String id);

  /// Hands saved inside the session.
  Future<int> handCount(String id);

  /// Final money fields on the session doc.
  Future<void> recordResult(
    String id, {
    double? currentStack,
    int? finishedPlace,
    int? fieldSize,
    double? prizeWon,
  });

  /// Sets `endTime` and (cloud) the user's session count + play time.
  Future<void> end(String id, DateTime at);

  /// Deletes the session AND every hand in it, in both stores.
  Future<void> discard(String id);
}

class TrackedSessionService {
  TrackedSessionService._();

  @visibleForTesting
  static TrackedSessionBackend backend = FirebaseTrackedSessionBackend();

  /// Seams for tests.
  @visibleForTesting
  static String Function() newId = FirebaseService.newSessionId;
  static DateTime Function() now = DateTime.now;
  static Future<void> Function(TrackedSession s) liveStart = (s) =>
      LiveSessionNotificationService.start(
        sessionId: s.id,
        name: s.name,
        gameType: s.gameType.value,
        startTime: s.startTime,
      );
  static Future<void> Function(String id) liveStop =
      LiveSessionNotificationService.stop;

  /// Starts a session now: saved at once (cloud + SQLite), so the timer can
  /// always derive from `startTime`, then posts the running notification.
  static Future<TrackedSession> start({
    required String name,
    required GameType gameType,
    required double buyIn,
    double? startingStack,
  }) async {
    if (buyIn <= 0) throw ArgumentError('Buy-in must be positive');
    // Service-level rule: nothing is created while another session runs.
    await SessionStartGate.assertNoRunning();
    final cash = gameType == GameType.cash;
    final session = TrackedSession(
      id: newId(),
      name: name.trim(),
      gameType: gameType,
      buyIn: buyIn,
      startingStack: cash ? buyIn : (startingStack ?? 0),
      startTime: now(),
    );
    await backend.create(session);
    AppDataCache.markSessionsDirty();
    AppDataCache.markHomeDirty();
    await liveStart(session);
    return session;
  }

  /// The tracked session running right now (the app-wide running record), or
  /// null. "+ > Log a hand" saves into it by default (D23).
  static Future<SingleHandSessionTarget?> runningTarget() async {
    final r = await currentRecord();
    if (r == null || r.kind != LiveSessionRecord.kindTracked) return null;
    return SingleHandSessionTarget(r.sessionId, r.name,
        r.gameType == 'tournament' ? GameType.tournament : GameType.cash);
  }

  /// The running FULL logging session as a (resume-only) target, or null.
  static Future<SingleHandSessionTarget?> runningFullTarget() async {
    final r = await currentRecord();
    if (r == null || r.kind != LiveSessionRecord.kindFull) return null;
    return SingleHandSessionTarget(r.sessionId, r.name,
        r.gameType == 'tournament' ? GameType.tournament : GameType.cash,
        isFull: true);
  }

  /// The one running session of any kind (full or tracked), or null.
  @visibleForTesting
  static Future<LiveSessionRecord?> Function() currentRecord =
      LiveSessionNotificationService.current;

  /// The hands saved inside session [id] (cloud first, SQLite fallback).
  @visibleForTesting
  static Future<List<Map<String, dynamic>>> Function(String id) handsLoader =
      (id) async {
    try {
      return await FirebaseService.getSessionHands(id);
    } catch (_) {
      return LocalStorageService.getSessionHands(id);
    }
  };

  static Future<List<Map<String, dynamic>>> loadHands(String id) =>
      handsLoader(id);

  /// The stored session doc (cloud first, SQLite fallback), or null.
  static Future<Map<String, dynamic>?> loadDoc(String id) => backend.load(id);

  static Future<TrackedSession?> load(String id) async {
    final m = await backend.load(id);
    return m == null ? null : TrackedSession.fromSession(id, m);
  }

  static Future<int> handCount(String id) async {
    try {
      return await backend.handCount(id);
    } catch (_) {
      return 0;
    }
  }

  /// Ends the session with the player's [result] (the bankroll sheet already
  /// wrote `session_results` and the bankroll). Cash keeps the cash-out as
  /// the final stack so Session History shows the P/L.
  static Future<void> finish(
    TrackedSession session, {
    required double totalBuyIn,
    TrackedSessionResult? result,
    DateTime? endTime,
  }) async {
    if (result != null) {
      await backend.recordResult(
        session.id,
        currentStack: session.gameType == GameType.cash
            ? totalBuyIn + result.profitLoss
            : null,
        finishedPlace: result.finishedPlace,
        fieldSize: result.fieldSize,
        prizeWon: result.prizeWon,
      );
    }
    await backend.end(session.id, endTime ?? now());
    AppDataCache.markSessionsDirty();
    AppDataCache.markHomeDirty();
    AppDataCache.markStatsDirty();
    await liveStop(session.id);
  }

  /// Writes a cash result like the end sheet does (bankroll + session_results).
  @visibleForTesting
  static Future<void> Function(double profit, double buyIn, int minutes)
      recordCashResult = (profit, buyIn, minutes) async {
    await BankrollService.addToBankroll(profit);
    await SessionResultService.addSessionResult(
      amount: profit,
      gameType: 'cash',
      buyInAmount: buyIn,
      durationMinutes: minutes,
    );
  };

  /// Ends a session without the end sheet (the running-session "Still
  /// playing?" prompt, or "end it first" when another session starts), at
  /// [end]. Cash is settled from the last stack the player entered. A
  /// tournament prize is unknown here, so no `session_results` row is written
  /// (a 0 prize would record a full loss). True when the session is closed.
  static Future<bool> endWithoutSheet(String id, DateTime end) async {
    final doc = await backend.load(id);
    final session = doc == null ? null : TrackedSession.fromSession(id, doc);
    if (doc == null || session == null) {
      await liveStop(id); // gone already: nothing left to end
      return true;
    }
    final buyIn = (doc['totalBuyIn'] as num?)?.toDouble() ?? session.buyIn;
    TrackedSessionResult? result;
    if (session.gameType == GameType.cash) {
      final stack =
          (doc['currentStack'] as num?)?.toDouble() ?? session.startingStack;
      result = TrackedSessionResult(profitLoss: stack - buyIn);
      await recordCashResult(
          result.profitLoss, buyIn, end.difference(session.startTime).inMinutes);
    }
    await finish(session, totalBuyIn: buyIn, result: result, endTime: end);
    return true;
  }

  /// Throws the session and its hands away (both stores).
  static Future<void> discard(String id) async {
    await backend.discard(id);
    AppDataCache.markSessionsDirty();
    AppDataCache.markHomeDirty();
    AppDataCache.markStatsDirty();
    await liveStop(id);
  }
}

/// Firestore + SQLite implementation. Offline: Firestore writes queue, so
/// awaited cloud writes get a timeout and a timeout is not an error.
class FirebaseTrackedSessionBackend implements TrackedSessionBackend {
  static const Duration _cloudWait = Duration(seconds: 4);
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> _queued(Future<void> write, String what) async {
    try {
      await write.timeout(_cloudWait);
    } on TimeoutException {
      await LoggerService.info('Tracked session: $what queued (offline?)');
    }
  }

  @override
  Future<void> create(TrackedSession s) async {
    await LocalStorageService.saveSession(
      sessionId: s.id,
      smallBlind: 0,
      bigBlind: 0,
      playerCount: 0,
      startTime: s.startTime.toIso8601String(),
      gameType: s.gameType,
      buyInAmount: s.buyIn,
      sessionType: kTrackedSessionType,
      sessionName: s.name,
    );
    await _queued(
      FirebaseService.createSession(
        smallBlind: 0,
        bigBlind: 0,
        playerCount: 0,
        gameType: s.gameType,
        sessionName: s.name,
        startingStack: s.startingStack,
        totalBuyIn: s.buyIn,
        sessionType: kTrackedSessionType,
        sessionId: s.id,
      ),
      'create',
    );
    // First stack-history point, so the hub chart and the history row have a
    // starting value (mirrors what the full-session setup writes).
    try {
      await _queued(
        FirebaseService.updateIndividualSession(
          sessionId: s.id,
          currentStack: s.startingStack,
          stackHistory: [
            {
              'timestamp': s.startTime.toIso8601String(),
              'stackSize': s.startingStack,
              'changeType': 'initial',
              'changeAmount': s.buyIn,
            }
          ],
        ),
        'initial stack',
      );
    } catch (e) {
      await LoggerService.warning('Tracked session: initial stack failed: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> load(String id) async {
    try {
      final doc =
          await _db.collection('poker_sessions').doc(id).get().timeout(_cloudWait);
      if (doc.exists) return {'id': doc.id, ...doc.data()!};
    } catch (_) {}
    return LocalStorageService.getSession(id);
  }

  @override
  Future<int> handCount(String id) async {
    try {
      final doc =
          await _db.collection('poker_sessions').doc(id).get().timeout(_cloudWait);
      final n = (doc.data()?['totalHands'] as num?)?.toInt();
      if (n != null) return n;
    } catch (_) {}
    final local = await LocalStorageService.getSession(id);
    return (local?['totalHands'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> recordResult(
    String id, {
    double? currentStack,
    int? finishedPlace,
    int? fieldSize,
    double? prizeWon,
  }) async {
    try {
      await _queued(
        FirebaseService.updateIndividualSession(
          sessionId: id,
          currentStack: currentStack,
          finishedPlace: finishedPlace,
          fieldSize: fieldSize,
          prizeWon: prizeWon,
        ),
        'result',
      );
    } catch (e) {
      await LoggerService.warning('Tracked session: result write failed: $e');
    }
  }

  @override
  Future<void> end(String id, DateTime at) async {
    await LocalStorageService.endSession(id, at.toIso8601String());
    try {
      // A real end time the player chose drives endTime and play time.
      final real = DateTime.now().difference(at) > const Duration(minutes: 1);
      await FirebaseService.endSession(id, endTime: real ? at : null)
          .timeout(_cloudWait);
    } on TimeoutException {
      await LoggerService.info('Tracked session: end queued (offline?)');
    } catch (e) {
      await LoggerService.warning('Tracked session: cloud end failed: $e');
    }
  }

  @override
  Future<void> discard(String id) async {
    if (AuthService.userId != null) await FirebaseService.deleteSession(id);
    await LocalStorageService.deleteSession(id);
  }
}
