import 'dart:async';

import '../models/hand_completeness.dart';
import '../models/hand_state_machine.dart';
import 'app_data_cache.dart';
import 'firebase_service.dart';
import 'local_storage_service.dart';
import 'logger_service.dart';
import 'range_grid_service.dart';

enum PromotionStatus { promoted, alreadyCounted, invalid, failed }

class PromotionResult {
  final PromotionStatus status;

  /// Time between flagging and completing (null when unknown). The caller
  /// passes it to HandLogTelemetry.captureFlagCompleted.
  final Duration? lag;

  const PromotionResult(this.status, {this.lag});

  static const alreadyCounted = PromotionResult(PromotionStatus.alreadyCounted);
  static const invalid = PromotionResult(PromotionStatus.invalid);
  static const failed = PromotionResult(PromotionStatus.failed);

  bool get promoted => status == PromotionStatus.promoted;
}

/// Writes hero stats for a promoted stub. Injected so the "exactly once"
/// rule is testable without Firebase.
abstract class HandStatsWriter {
  Future<void> applyPromotedStats(HandRecord hand);
  Future<void> incrementSessionTotalHands(String sessionId);
}

/// Storage side of a promotion (transactional claim + local mirror).
abstract class PromotionStore {
  /// Returns false when the stub was already counted (nothing written).
  Future<bool> claim({
    required String sessionId,
    required String cloudHandId,
    required Map<String, dynamic> fields,
  });

  Future<void> mirrorLocal({
    required String localHandId,
    required Map<String, dynamic> fields,
  });

  void markCachesDirty();
}

class FirebaseHandStatsWriter implements HandStatsWriter {
  @override
  Future<void> applyPromotedStats(HandRecord hand) {
    return FirebaseService.applyStatsForPromotedHand(
      actions: hand.actions.map((a) => a.toMap()).toList(),
      heroPositionName: hand.heroPositionName,
      heroSeatNumber: hand.heroSeatNumber,
      winnerId: hand.winnerId,
      choppedWinners: hand.choppedWinners,
    );
  }

  @override
  Future<void> incrementSessionTotalHands(String sessionId) =>
      FirebaseService.incrementSessionTotalHands(sessionId);
}

class FirebasePromotionStore implements PromotionStore {
  @override
  Future<bool> claim({
    required String sessionId,
    required String cloudHandId,
    required Map<String, dynamic> fields,
  }) =>
      FirebaseService.claimStubPromotion(
          sessionId: sessionId, handId: cloudHandId, fields: fields);

  @override
  Future<void> mirrorLocal({
    required String localHandId,
    required Map<String, dynamic> fields,
  }) async {
    await LocalStorageService.updateHandPromotion(
        handId: localHandId, fields: fields);
  }

  @override
  void markCachesDirty() {
    AppDataCache.markHomeDirty();
    AppDataCache.markSessionsDirty();
    AppDataCache.markStatsDirty();
  }
}

/// Promotes a flagged stub to a reconstructed hand and applies its stats
/// EXACTLY ONCE (invariants I30, I33).
class HandPromotionService {
  final HandStatsWriter stats;
  final PromotionStore store;
  final DateTime Function() _now;

  /// Indexes the promoted hand in the range grid (only runs with hole cards).
  final Future<void> Function(HandRecord hand, String sessionId,
      String? localHandId, double bigBlind, String gameType)? rangeIndexer;

  HandPromotionService({
    HandStatsWriter? stats,
    PromotionStore? store,
    DateTime Function()? now,
    this.rangeIndexer,
  })  : stats = stats ?? FirebaseHandStatsWriter(),
        store = store ?? FirebasePromotionStore(),
        _now = now ?? DateTime.now;

  /// Pure: the Firestore/local field map written at promotion.
  static Map<String, dynamic> promotionFields(HandRecord h) {
    final m = h.toMap();
    return {
      'actions': m['actions'],
      if (m['boardCards'] != null) 'boardCards': m['boardCards'],
      if (m['ourHoleCards'] != null) 'ourHoleCards': m['ourHoleCards'],
      if (m['showdownData'] != null) 'showdownData': m['showdownData'],
      'reachedShowdown': h.reachedShowdown,
      'potAmount': h.potAmount,
      'preflopPot': h.preflopPot,
      'flopPot': h.flopPot,
      'turnPot': h.turnPot,
      'riverPot': h.riverPot,
      if (h.winnerId != null) 'winnerId': h.winnerId,
      if (h.heroPositionName != null) 'heroPositionName': h.heroPositionName,
      if (h.heroSeatNumber != null) 'heroSeatNumber': h.heroSeatNumber,
      'isChoppedPot': h.isChoppedPot,
      'isSplitPot': h.isSplitPot,
      if (h.choppedWinners != null) 'choppedWinners': h.choppedWinners,
      if (m['individualShares'] != null) 'individualShares': m['individualShares'],
      if (h.sharePerWinner != null) 'sharePerWinner': h.sharePerWinner,
      if (h.flagMeta != null) 'flag': h.flagMeta,
    };
  }

  /// Pure validation: non-empty actions and a counting target level.
  static bool isValidTarget(HandRecord completed) =>
      completed.actions.isNotEmpty &&
      (completed.completeness == HandCompleteness.reconstructed ||
          completed.completeness == HandCompleteness.full);

  Future<PromotionResult> promote({
    required String sessionId,
    required String cloudHandId,
    String? localHandId,
    required HandRecord completed,
    double? bigBlind,
    String? gameType,
  }) async {
    if (!isValidTarget(completed)) return PromotionResult.invalid;
    final fields = promotionFields(completed);
    final bool claimed;
    try {
      // The statsApplied flip happens here, BEFORE any stats call.
      claimed = await store.claim(
          sessionId: sessionId, cloudHandId: cloudHandId, fields: fields);
    } catch (e) {
      await LoggerService.error('Stub promotion claim failed', e, StackTrace.current);
      return PromotionResult.failed;
    }
    if (!claimed) return PromotionResult.alreadyCounted;

    await _applyOnce(sessionId, completed);
    await _mirror(localHandId, sessionId, completed, fields, bigBlind, gameType);
    store.markCachesDirty();
    return PromotionResult(PromotionStatus.promoted, lag: _lag(completed));
  }

  Future<void> _applyOnce(String sessionId, HandRecord completed) async {
    try {
      await stats.applyPromotedStats(completed);
      await stats.incrementSessionTotalHands(sessionId);
    } catch (e) {
      // Under-count (acceptable); never retried, so never double-counted.
      await LoggerService.error('Promotion stats failed', e, StackTrace.current);
    }
  }

  Future<void> _mirror(String? localHandId, String sessionId, HandRecord h,
      Map<String, dynamic> fields, double? bigBlind, String? gameType) async {
    if (localHandId == null) return;
    try {
      await store.mirrorLocal(localHandId: localHandId, fields: {
        ...fields,
        'sessionId': sessionId,
        'endTime': _now().toIso8601String(),
      });
      if (bigBlind != null && gameType != null) {
        final indexer = rangeIndexer;
        if (indexer != null) {
          unawaited(indexer(h, sessionId, localHandId, bigBlind, gameType));
        } else {
          unawaited(RangeGridService.indexHand(
              hand: h,
              handId: localHandId,
              sessionId: sessionId,
              heroSeat: h.heroSeatNumber,
              bigBlind: bigBlind,
              gameType: gameType));
        }
      }
    } catch (e) {
      await LoggerService.error('Promotion local mirror failed', e, StackTrace.current);
    }
  }

  Duration? _lag(HandRecord h) {
    final raw = h.flagMeta?['flaggedAt'];
    final at = raw is String ? DateTime.tryParse(raw) : null;
    return at == null ? null : _now().difference(at);
  }
}
