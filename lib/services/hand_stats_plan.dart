import '../models/hand_completeness.dart';
import 'stats_calculator.dart';

/// Which hero counters a hand of a given completeness may touch.
enum HeroStatsMode { none, totalsOnly, preflopOnly, full }

/// Single gate: completeness -> hero stats mode. See the gating matrix in
/// docs/hand-logging-completeness.md.
HeroStatsMode heroModeFor(HandCompleteness c) {
  switch (c) {
    case HandCompleteness.flagged:
      return HeroStatsMode.none;
    case HandCompleteness.foldTick:
      return HeroStatsMode.totalsOnly;
    case HandCompleteness.preflop:
      return HeroStatsMode.preflopOnly;
    case HandCompleteness.reconstructed:
    case HandCompleteness.full:
      return HeroStatsMode.full;
  }
}

bool opponentsFeedFor(HandCompleteness c) => c.countsForOpponentStats;

/// Counter deltas one hand adds to the hero's `user_stats`. Pure value.
class HeroHandDelta {
  final int totalHands, walks, hands, vpip, pfr, threeBet, threeBetOpp;
  final int fold3bet, facing3Bet, cbet, cbetOpp, steal, stealOpp;
  final int checkRaiseFlop, checkRaiseFlopOpp, blindDefend, blindDefendOpp;
  final int wonHands;
  final String? position;

  const HeroHandDelta({
    this.totalHands = 0,
    this.walks = 0,
    this.hands = 0,
    this.vpip = 0,
    this.pfr = 0,
    this.threeBet = 0,
    this.threeBetOpp = 0,
    this.fold3bet = 0,
    this.facing3Bet = 0,
    this.cbet = 0,
    this.cbetOpp = 0,
    this.steal = 0,
    this.stealOpp = 0,
    this.checkRaiseFlop = 0,
    this.checkRaiseFlopOpp = 0,
    this.blindDefend = 0,
    this.blindDefendOpp = 0,
    this.wonHands = 0,
    this.position,
  });

  /// Delta of a fold tick: `totalHands + 1`, nothing else (same as the
  /// legacy Skip hand). Position stays null on purpose (arithmetic parity).
  static const foldTick = HeroHandDelta(totalHands: 1);

  /// Copy with the outcome-dependent counters zeroed (preflop-level hands).
  HeroHandDelta preflopOnly() => HeroHandDelta(
        totalHands: totalHands,
        walks: walks,
        vpip: vpip,
        pfr: pfr,
        threeBet: threeBet,
        threeBetOpp: threeBetOpp,
        fold3bet: fold3bet,
        facing3Bet: facing3Bet,
        steal: steal,
        stealOpp: stealOpp,
        blindDefend: blindDefend,
        blindDefendOpp: blindDefendOpp,
        position: position,
      );

  bool get isEmpty =>
      totalHands == 0 &&
      walks == 0 &&
      hands == 0 &&
      vpip == 0 &&
      pfr == 0 &&
      threeBet == 0 &&
      threeBetOpp == 0 &&
      fold3bet == 0 &&
      facing3Bet == 0 &&
      cbet == 0 &&
      cbetOpp == 0 &&
      steal == 0 &&
      stealOpp == 0 &&
      checkRaiseFlop == 0 &&
      checkRaiseFlopOpp == 0 &&
      blindDefend == 0 &&
      blindDefendOpp == 0 &&
      wonHands == 0;
}

/// Pure: computes the hero delta for one hand. [mode] full reproduces the
/// historical `_updateUserStatsFromHand` arithmetic exactly.
HeroHandDelta computeHeroDelta({
  required List<Map<String, dynamic>> actions,
  required String? heroPositionName,
  required int? heroSeatNumber,
  required int? winnerId,
  List<int>? choppedWinners,
  HeroStatsMode mode = HeroStatsMode.full,
}) {
  if (mode == HeroStatsMode.none) return const HeroHandDelta();
  if (mode == HeroStatsMode.totalsOnly) return HeroHandDelta.foldTick;
  final seat = heroSeatNumber;
  if (seat == null || heroPositionName == null) return const HeroHandDelta();
  final full = _fullDelta(
      actions, heroPositionName, seat, winnerId, choppedWinners);
  return mode == HeroStatsMode.preflopOnly ? full.preflopOnly() : full;
}

HeroHandDelta _fullDelta(List<Map<String, dynamic>> actions, String position,
    int seat, int? winnerId, List<int>? choppedWinners) {
  final didWin = (winnerId != null && winnerId == seat) ||
      (choppedWinners?.contains(seat) ?? false);
  var didPlay = false, didVpip = false, didPfr = false;
  for (final a in actions) {
    if (a['player'] != seat) continue;
    final type = a['action']?.toString().toLowerCase() ?? '';
    final street = a['street']?.toString().toLowerCase() ?? '';
    const playing = {'call', 'bet', 'raise', 'all-in', 'check'};
    if (playing.contains(type)) didPlay = true;
    if (street == 'preflop' &&
        {'bet', 'call', 'raise', 'all-in'}.contains(type)) {
      if (!StatsCalculator.isBlindAction(a)) didVpip = true;
      if (type == 'bet' || type == 'raise' || type == 'all-in') didPfr = true;
    }
  }
  final didThreeBet =
      didPlay && StatsCalculator.didPlayerThreeBet(actions, seat);
  final isBBWalk =
      StatsCalculator.isWalkHand(actions) && StatsCalculator.isBigBlind(actions, seat);
  final cbetOpp = StatsCalculator.hadCbetOpportunity(actions, seat);
  final stealOpp = StatsCalculator.hadStealOpportunity(actions, seat);
  final crOpp = StatsCalculator.hadCheckRaiseFlopOpportunity(actions, seat);
  final bdOpp = StatsCalculator.hadBlindDefendOpportunity(actions, seat);
  return HeroHandDelta(
    totalHands: 1,
    walks: isBBWalk ? 1 : 0,
    hands: didPlay ? 1 : 0,
    vpip: didVpip ? 1 : 0,
    pfr: didPfr ? 1 : 0,
    threeBet: didThreeBet ? 1 : 0,
    threeBetOpp: StatsCalculator.hadThreeBetOpportunity(actions, seat) ? 1 : 0,
    fold3bet: StatsCalculator.didFoldTo3Bet(actions, seat) ? 1 : 0,
    facing3Bet: StatsCalculator.facedThreeBet(actions, seat) ? 1 : 0,
    cbet: cbetOpp && StatsCalculator.didCbet(actions, seat) ? 1 : 0,
    cbetOpp: cbetOpp ? 1 : 0,
    steal: stealOpp && StatsCalculator.didSteal(actions, seat) ? 1 : 0,
    stealOpp: stealOpp ? 1 : 0,
    checkRaiseFlop:
        crOpp && StatsCalculator.didCheckRaiseFlop(actions, seat) ? 1 : 0,
    checkRaiseFlopOpp: crOpp ? 1 : 0,
    blindDefend:
        bdOpp && StatsCalculator.didBlindDefend(actions, seat) ? 1 : 0,
    blindDefendOpp: bdOpp ? 1 : 0,
    wonHands: didWin && didPlay ? 1 : 0,
    position: position,
  );
}
