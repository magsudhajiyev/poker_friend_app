import 'package:shared_preferences/shared_preferences.dart';
import '../utils/poker_positions.dart';
import 'opponent_service.dart';
import 'opponent_stats_service.dart';

/// Result of the skip-hand scouting prompt.
enum SkipScoutAction { noRaise, raised }

class SkipScoutResult {
  final SkipScoutAction action;
  final int? raiserSeat; // only set for [SkipScoutAction.raised]

  const SkipScoutResult.noRaise()
      : action = SkipScoutAction.noRaise,
        raiserSeat = null;

  const SkipScoutResult.raised(this.raiserSeat)
      : action = SkipScoutAction.raised;
}

/// Service to track opponent stats on hands the hero skipped (folded preflop).
///
/// When enabled, a quick prompt asks "what happened?" after the user taps
/// Next Hand, so opponent VPIP/PFR denominators stay accurate.
class SkipHandScoutingService {
  static const _key = 'skip_hand_scouting_enabled';
  static bool _enabled = false;

  /// Load preference on app startup.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? false;
  }

  /// Whether the scouting prompt is enabled.
  static bool get isEnabled => _enabled;

  /// Persist the toggle.
  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  /// Steal-eligible positions.
  static const _stealPositions = {'CO', 'BTN', 'SB', 'BTN/SB'};

  /// Apply opponent stat deltas based on the scouting result.
  ///
  /// [playerNames] — seat number → display name (from sessionManager).
  /// [activeSeats] — set of active seat numbers this hand.
  /// [heroSeat]    — the hero's seat number (excluded from updates).
  /// [buttonPosition] — current button seat.
  static Future<void> applySkipDeltas({
    required SkipScoutResult result,
    required Map<int, String> playerNames,
    required Set<int> activeSeats,
    required int heroSeat,
    required int buttonPosition,
  }) async {
    // Load all saved opponents to match names → IDs.
    final opponents = await OpponentService.getAllOpponents();
    final nameLower = <String, String>{};
    for (final o in opponents) {
      nameLower[o.name.toLowerCase()] = o.id;
    }

    // Build seat → position map.
    final sortedSeats = activeSeats.toList()..sort();
    final seatPosition = <int, String>{};
    for (final seat in sortedSeats) {
      seatPosition[seat] = PokerPositions.getPositionNameForActivePlayers(
        seat,
        buttonPosition,
        sortedSeats,
      );
    }

    // Build preflop action order (UTG first, SB/BB last).
    final preflopOrder = _preflopActionOrder(buttonPosition, sortedSeats);

    // Determine raiser index in the action order (for steal-opportunity logic).
    int? raiserOrderIndex;
    if (result.action == SkipScoutAction.raised && result.raiserSeat != null) {
      raiserOrderIndex = preflopOrder.indexOf(result.raiserSeat!);
    }

    for (final seat in sortedSeats) {
      if (seat == heroSeat) continue;

      final name = playerNames[seat];
      if (name == null) continue;

      // Only update saved opponents (skip position-named placeholders).
      if (PokerPositions.isPositionName(name)) continue;

      final opponentId = nameLower[name.toLowerCase()];
      if (opponentId == null) continue;

      final position = seatPosition[seat] ?? '';
      final isStealPosition = _stealPositions.contains(position);

      if (result.action == SkipScoutAction.noRaise) {
        // Nobody raised — every opponent gets +1 hand.
        // Steal-position opponents had an opportunity but didn't steal.
        await OpponentStatsService.updateStatsAtomic(
          opponentId: opponentId,
          handsDelta: 1,
          stealOpportunityDelta: isStealPosition ? 1 : 0,
        );
      } else if (result.action == SkipScoutAction.raised) {
        final isRaiser = seat == result.raiserSeat;

        if (isRaiser) {
          // The raiser: VPIP + PFR + hand.
          await OpponentStatsService.updateStatsAtomic(
            opponentId: opponentId,
            handsDelta: 1,
            vpipDelta: 1,
            pfrDelta: 1,
            raiseDelta: 1,
            aggressionDelta: 1,
            stealCountDelta: isStealPosition ? 1 : 0,
            stealOpportunityDelta: isStealPosition ? 1 : 0,
          );
        } else {
          // Non-raiser: +1 hand.
          // Steal opportunity only if they acted BEFORE the raiser
          // (pot was still unopened when it was their turn).
          int stealOpp = 0;
          if (isStealPosition && raiserOrderIndex != null) {
            final myIndex = preflopOrder.indexOf(seat);
            if (myIndex != -1 && myIndex < raiserOrderIndex) {
              stealOpp = 1;
            }
          }
          await OpponentStatsService.updateStatsAtomic(
            opponentId: opponentId,
            handsDelta: 1,
            stealOpportunityDelta: stealOpp,
          );
        }
      }
    }
  }

  /// Compute preflop action order for [activeSeats] given [buttonPosition].
  /// Returns seats ordered UTG → … → CO → BTN → SB → BB.
  static List<int> _preflopActionOrder(
    int buttonPosition,
    List<int> sortedActiveSeats,
  ) {
    if (sortedActiveSeats.length <= 1) return List.from(sortedActiveSeats);

    final n = sortedActiveSeats.length;

    // Find button index.
    int btnIdx = sortedActiveSeats.indexOf(buttonPosition);
    if (btnIdx == -1) {
      // Button not in active seats — find closest clockwise.
      for (int i = 0; i < sortedActiveSeats.length; i++) {
        if (sortedActiveSeats[i] > buttonPosition) {
          btnIdx = i;
          break;
        }
      }
      btnIdx = btnIdx == -1 ? 0 : btnIdx;
    }

    // SB = btn+1, BB = btn+2, UTG = btn+3 (for 3+ players).
    // For heads-up: BTN/SB acts first, BB second.
    if (n == 2) {
      return [
        sortedActiveSeats[btnIdx],
        sortedActiveSeats[(btnIdx + 1) % n],
      ];
    }

    // UTG is 3 positions after button.
    final utgIdx = (btnIdx + 3) % n;
    final order = <int>[];
    for (int i = 0; i < n; i++) {
      order.add(sortedActiveSeats[(utgIdx + i) % n]);
    }
    return order;
  }
}
