import '../models/hand_completeness.dart';
import '../models/hand_state_machine.dart';
import 'stats_calculator.dart';
import 'villain_tracker.dart';

/// Minimum samples per insight (each insight shows its n).
const int kInsightMinOpens = 3;
const int kInsightMinCbetSpots = 3;
const int kInsightMinNoFlop = 5;
const int kInsightMinHandsForBiggestPot = 5;

enum HandInsightKind { opens, foldCbet, biggestPot, noFlop }

/// ONE post-hand insight: kind + numbers (rendered with l10n by the UI).
class HandInsight {
  final HandInsightKind kind;

  /// Sample size shown to the user (open number, spots, hands in a row).
  final int n;
  final String? position;
  final int? pct;

  const HandInsight(this.kind, {required this.n, this.position, this.pct});

  @override
  bool operator ==(Object other) =>
      other is HandInsight &&
      other.kind == kind &&
      other.n == n &&
      other.position == position &&
      other.pct == pct;

  @override
  int get hashCode => Object.hash(kind, n, position, pct);
}

/// What the hero did in one hand, derived once with [StatsCalculator].
class _HeroHand {
  final int pot;
  final bool sawFlop;
  final String? openPosition;
  final bool? foldedToCbet; // null = did not face a c-bet

  const _HeroHand(this.pot, this.sawFlop, this.openPosition, this.foldedToCbet);
}

_HeroHand? _readHand(Map<String, dynamic> hand) {
  if (!HandCompletenessX.fromHandMap(hand).isAnalyzable) return null;
  if (hand['isScouted'] == true) return null;
  final hero = hand['heroSeatNumber'] as int?;
  final actions = handActionMaps(hand);
  if (hero == null || actions.isEmpty) return null;
  final pot = ((hand['potAmount'] as num?) ?? 0).toDouble();
  final heroFolded = StatsCalculator.playerFoldedPreflop(actions, hero);
  final sawFlop = !heroFolded &&
      actions.any((a) => a['street']?.toString().toLowerCase() == 'flop');
  final spot = findCbetSpot(actions);
  return _HeroHand(
    pot.round(),
    sawFlop,
    _openPosition(actions, hero, hand['heroPositionName'] as String?),
    spot != null && spot.aggressor != hero ? spot.responses[hero] : null,
  );
}

String? _openPosition(List<Map<String, dynamic>> acts, int hero, String? pos) {
  if (pos == null) return null;
  for (final a in acts) {
    if (a['street']?.toString().toLowerCase() != 'preflop') continue;
    if (!StatsCalculator.isRaiseAction(a['action']?.toString() ?? '')) continue;
    return a['player'] == hero ? pos : null; // first voluntary raise only
  }
  return null;
}

/// Session tallies of the HERO's logged hands. [record] AFTER you computed
/// the insight for that hand (insightFor expects the tallies WITHOUT it).
class SessionTallies {
  int hands = 0;
  double maxPot = 0;
  int noFlopStreak = 0;
  int cbetSpots = 0;
  int cbetFolds = 0;
  final Map<String, int> opensByPosition = {};

  void reset() {
    hands = 0;
    maxPot = 0;
    noFlopStreak = 0;
    cbetSpots = 0;
    cbetFolds = 0;
    opensByPosition.clear();
  }

  void record(Map<String, dynamic> hand) {
    final h = _readHand(hand);
    if (h == null) return;
    hands++;
    if (h.pot > maxPot) maxPot = h.pot.toDouble();
    noFlopStreak = h.sawFlop ? 0 : noFlopStreak + 1;
    final folded = h.foldedToCbet;
    if (folded != null) {
      cbetSpots++;
      if (folded) cbetFolds++;
    }
    final p = h.openPosition;
    if (p != null) opensByPosition[p] = (opensByPosition[p] ?? 0) + 1;
  }
}

/// Picks ONE insight for [hand] (a just-completed record), or null. Pure.
/// [tallies] must NOT yet contain [hand].
HandInsight? insightFor(HandRecord hand, SessionTallies tallies) {
  final h = _readHand(hand.toMap());
  if (h == null) return null;
  if (tallies.hands >= kInsightMinHandsForBiggestPot && h.pot > tallies.maxPot) {
    return HandInsight(HandInsightKind.biggestPot, n: tallies.hands + 1);
  }
  final folded = h.foldedToCbet;
  if (folded != null && tallies.cbetSpots + 1 >= kInsightMinCbetSpots) {
    final n = tallies.cbetSpots + 1;
    final f = tallies.cbetFolds + (folded ? 1 : 0);
    return HandInsight(HandInsightKind.foldCbet, n: n, pct: (f * 100 / n).round());
  }
  final pos = h.openPosition;
  if (pos != null) {
    final n = (tallies.opensByPosition[pos] ?? 0) + 1;
    if (n >= kInsightMinOpens) {
      return HandInsight(HandInsightKind.opens, n: n, position: pos);
    }
  }
  if (!h.sawFlop && tallies.noFlopStreak + 1 >= kInsightMinNoFlop) {
    return HandInsight(HandInsightKind.noFlop, n: tallies.noFlopStreak + 1);
  }
  return null;
}
