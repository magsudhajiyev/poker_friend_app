import '../models/hand_completeness.dart';
import '../models/hand_state_machine.dart';
import 'hand_flag_service.dart';
import 'hand_log_telemetry.dart';
import 'hand_promotion_service.dart';

/// Finishes a flagged stub from recall mode: the hand logged on the throw-away
/// recall table becomes the stub's content. Stats are applied by
/// [HandPromotionService] exactly once; nothing else is written.
class RecallFinisher {
  RecallFinisher._();

  /// Makes sure the promoted hand carries hero cards + position + seat, taking
  /// the stub's own values when the throw-away manager did not set them.
  static void backfillHeroInfo(HandRecord hand, FlaggedHandRef ref) {
    final c = ref.heroCards;
    if (hand.ourHoleCards == null && c != null) {
      hand.ourHoleCards =
          HoleCards(card1: c['card1'] as String?, card2: c['card2'] as String?);
    }
    final table = ref.table;
    final seat = table?.heroSeat;
    hand.heroSeatNumber ??= seat;
    if ((hand.heroPositionName ?? '').isEmpty) {
      String? pos = ref.heroPositionName;
      if (seat != null && table != null) {
        for (final s in table.seats) {
          if (s.seat == seat && (s.position ?? '').isNotEmpty) pos = s.position;
        }
      }
      if ((pos ?? '').isNotEmpty) hand.heroPositionName = pos;
    }
  }

  /// Promotes [ref] with [hand] (the recall manager's finished hand).
  /// Returns the promotion result, or null when there is nothing to promote.
  static Future<PromotionResult?> finish({
    required FlaggedHandRef ref,
    required HandRecord? hand,
    HandPromotionService? service,
    double? heroDelta,
  }) async {
    final cloudId = ref.cloudId;
    if (hand == null || cloudId == null) return null;
    hand.completeness = HandCompleteness.reconstructed;
    backfillHeroInfo(hand, ref);
    hand.flagMeta = Map<String, dynamic>.of(ref.flagMeta);
    if (heroDelta != null) {
      // Signed chips/money the hero won or lost, at the stub's own level.
      hand.flagMeta!['heroDelta'] = heroDelta;
      hand.flagMeta!['heroDeltaSource'] = 'recall';
    }
    final result = await (service ?? HandPromotionService()).promote(
      sessionId: ref.sessionId,
      cloudHandId: cloudId,
      localHandId: ref.localId,
      completed: hand,
      bigBlind: (ref.flagMeta['bigBlind'] as num?)?.toDouble(),
      gameType: ref.flagMeta['gameType'] as String?,
    );
    final lag = result.lag;
    if (result.promoted && lag != null) {
      HandLogTelemetry.captureFlagCompleted(lag.inMinutes);
    }
    return result;
  }
}
