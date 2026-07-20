import 'package:shared_preferences/shared_preferences.dart';
import '../utils/poker_positions.dart';
import 'firebase_service.dart';

/// What a single opponent did preflop in a scouted (hero-folded) hand.
enum SkipSeatAction { fold, call, raise }

/// What the original opener (1st raiser) did when facing a 3-bet.
/// Only meaningful when the pot was 3-bet.
enum OpenerResponse { fold, call, fourBet }

/// Result of the skip-hand scouting prompt.
///
/// Two shapes:
/// - [SkipScoutResult.noRaise] — nobody opened (folded around to the BB).
/// - [SkipScoutResult.detailed] — per-seat preflop actions, with raises ordered
///   by [raiseOrder] (1st = open, 2nd = 3-bet, …) and an optional
///   [openerResponse] describing what the opener did facing a 3-bet.
class SkipScoutResult {
  final bool anyRaise;

  /// seat → what that opponent did preflop (fold/call/raise). Hero excluded.
  final Map<int, SkipSeatAction> seatActions;

  /// Seats that raised, in the order they acted (1st = open, 2nd = 3-bet, …).
  final List<int> raiseOrder;

  /// What the opener did facing a 3-bet (null when not a 3-bet pot).
  final OpenerResponse? openerResponse;

  /// Nobody opened the pot — folded around to the big blind.
  const SkipScoutResult.noRaise()
      : anyRaise = false,
        seatActions = const {},
        raiseOrder = const [],
        openerResponse = null;

  /// A detailed per-seat capture.
  const SkipScoutResult.detailed({
    required this.seatActions,
    required this.raiseOrder,
    this.openerResponse,
  }) : anyRaise = true;
}

/// Service to track opponent stats on hands the hero skipped (folded preflop).
///
/// When enabled, a quick prompt asks "what happened?" after the user taps
/// Next Hand. The captured preflop actions are synthesized into an action list
/// and fed through the SAME opponent-stats pipeline used for fully-logged hands
/// ([FirebaseService.updateOpponentStatsFromHand]), so 3-Bet / Fold-to-3Bet /
/// Steal / Blind-Defend / VPIP / PFR are computed identically.
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

  /// Apply opponent stat deltas based on the scouting result by synthesizing a
  /// preflop action list and routing it through the shared stats pipeline.
  ///
  /// [playerNames]    — seat number → display name (from sessionManager).
  /// [activeSeats]    — set of active seat numbers this hand.
  /// [heroSeat]       — the hero's seat number (excluded from updates).
  /// [buttonPosition] — current button seat.
  static Future<void> applyScoutResult({
    required SkipScoutResult result,
    required Map<int, String> playerNames,
    required Set<int> activeSeats,
    required int heroSeat,
    required int buttonPosition,
  }) async {
    final actions = buildPreflopActions(
      result: result,
      playerNames: playerNames,
      activeSeats: activeSeats,
      heroSeat: heroSeat,
      buttonPosition: buttonPosition,
    );
    if (actions.isEmpty) return;

    // reachedShowdown: false — scouting is preflop-only, so postflop stats
    // (c-bet, check-raise, showdown) legitimately don't fire.
    await FirebaseService.updateOpponentStatsFromHand(
      actions: actions,
      playerNames: playerNames,
      reachedShowdown: false,
    );
  }

  /// Synthesize an ordered preflop action list from a scouting result.
  ///
  /// Emits: SB/BB blind posts, the hero's fold, then each active opponent's
  /// preflop action in UTG→BB order. Raises are placed using [raiseOrder] so
  /// the 1st raise is the open and the 2nd is a 3-bet. An [OpenerResponse]
  /// appends the opener's follow-up action after the 3-bet (enabling
  /// fold-to-3-bet detection).
  ///
  /// Each entry: `{player, action, street:'preflop', playerPosition}`. Actions
  /// carry no amount (not needed by the detectors).
  static List<Map<String, dynamic>> buildPreflopActions({
    required SkipScoutResult result,
    required Map<int, String> playerNames,
    required Set<int> activeSeats,
    required int heroSeat,
    required int buttonPosition,
  }) {
    final sortedSeats = activeSeats.toList()..sort();
    if (sortedSeats.length < 2) return const [];

    // Position for each seat (for steal/blind-defend detection).
    final seatPosition = <int, String>{};
    for (final seat in sortedSeats) {
      seatPosition[seat] = PokerPositions.getPositionNameForActivePlayers(
        seat,
        buttonPosition,
        sortedSeats,
      );
    }

    final order = _preflopActionOrder(buttonPosition, sortedSeats);
    final sbSeat = _blindSeat(order, isBigBlind: false);
    final bbSeat = _blindSeat(order, isBigBlind: true);

    final actions = <Map<String, dynamic>>[];

    Map<String, dynamic> entry(int seat, String action) => {
          'player': seat,
          'action': action,
          'street': 'preflop',
          'playerPosition': seatPosition[seat] ?? '',
        };

    // 1. Blind posts (forced — not raises; the detectors exclude them).
    if (sbSeat != null) actions.add(entry(sbSeat, 'small blind'));
    if (bbSeat != null) actions.add(entry(bbSeat, 'big blind'));

    // 2. Hero folds (they skipped this hand).
    actions.add(entry(heroSeat, 'fold'));

    if (!result.anyRaise) {
      // Folded around to the BB: everyone else folds. This yields a walk for
      // the BB and steal opportunities for late-position seats.
      for (final seat in order) {
        if (seat == heroSeat || seat == bbSeat) continue;
        actions.add(entry(seat, 'fold'));
      }
      return actions;
    }

    // 3. Detailed capture. Map raise seats to their order index so the 1st
    //    raise is the open and the 2nd is the 3-bet.
    final raiseIndex = <int, int>{};
    for (var i = 0; i < result.raiseOrder.length; i++) {
      raiseIndex[result.raiseOrder[i]] = i;
    }
    final opener = result.raiseOrder.isNotEmpty ? result.raiseOrder.first : null;

    // Emit each opponent's single preflop action in position order. Raises are
    // emitted in their captured order regardless of seat position so the
    // synthetic sequence matches how the hand actually played.
    //
    // Strategy: walk the position order; when we reach a raiser, we still emit
    // in position order EXCEPT we must guarantee the open precedes the 3-bet.
    // Since raiseOrder is the source of truth for raise sequencing, we emit
    // non-raise actions in position order and splice raises at the point of the
    // lowest-order not-yet-emitted raiser, preserving open→3-bet ordering.
    final emittedRaisers = <int>{};
    final pendingRaisers = List<int>.from(result.raiseOrder);

    for (final seat in order) {
      if (seat == heroSeat) continue;
      final action = result.seatActions[seat] ?? SkipSeatAction.fold;

      if (action == SkipSeatAction.raise) {
        // Emit any earlier-ordered raisers that sit later in position first,
        // so open always precedes 3-bet even if the 3-bettor is earlier in
        // seat order (e.g. a squeeze from the blinds after a LP open).
        while (pendingRaisers.isNotEmpty &&
            (raiseIndex[pendingRaisers.first] ?? 0) <
                (raiseIndex[seat] ?? 0)) {
          final r = pendingRaisers.removeAt(0);
          if (emittedRaisers.add(r)) actions.add(entry(r, 'raise'));
        }
        if (!emittedRaisers.contains(seat)) {
          actions.add(entry(seat, 'raise'));
          emittedRaisers.add(seat);
          pendingRaisers.remove(seat);
        }
      } else if (action == SkipSeatAction.call) {
        actions.add(entry(seat, 'call'));
      } else {
        actions.add(entry(seat, 'fold'));
      }
    }
    // Emit any raisers not reached in the position walk (safety).
    for (final r in pendingRaisers) {
      if (emittedRaisers.add(r)) actions.add(entry(r, 'raise'));
    }

    // 4. Opener's response to a 3-bet (only when there was a 3-bet).
    final wasThreeBet = result.raiseOrder.length >= 2;
    if (wasThreeBet && opener != null && result.openerResponse != null) {
      switch (result.openerResponse!) {
        case OpenerResponse.fold:
          actions.add(entry(opener, 'fold'));
          break;
        case OpenerResponse.call:
          actions.add(entry(opener, 'call'));
          break;
        case OpenerResponse.fourBet:
          actions.add(entry(opener, 'raise'));
          break;
      }
    }

    return actions;
  }

  /// Public: preflop action order (UTG → … → SB → BB) for the given active
  /// seats and button. Used by the scouting sheet to list opponents
  /// consistently from UTG down.
  static List<int> preflopActionOrder(int buttonPosition, Set<int> activeSeats) {
    final sorted = activeSeats.toList()..sort();
    return _preflopActionOrder(buttonPosition, sorted);
  }

  /// The SB (or BB) seat given the preflop action [order] (UTG→…→SB→BB).
  /// Heads-up: order is [BTN/SB, BB], so SB=first, BB=last.
  static int? _blindSeat(List<int> order, {required bool isBigBlind}) {
    if (order.length < 2) return null;
    return isBigBlind ? order.last : order[order.length - 2];
  }

  /// Compute preflop action order for [sortedActiveSeats] given [buttonPosition].
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
