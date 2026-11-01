import '../models/hand_completeness.dart';
import 'stats_calculator.dart';

/// Minimum denominator before any payoff line is shown (hard rule).
const int kPayoffMinSample = 3;

/// Which tally a [VillainLine] reports.
enum VillainLineKind { foldedToCbet, foldedTo3Bet, threeBets, vpip }

/// Structured payoff line: [count] of [total] (always [total] >= 3).
class VillainLine {
  final VillainLineKind kind;
  final int seat;
  final int count;
  final int total;

  const VillainLine({
    required this.kind,
    required this.seat,
    required this.count,
    required this.total,
  });

  @override
  bool operator ==(Object other) =>
      other is VillainLine &&
      other.kind == kind &&
      other.seat == seat &&
      other.count == count &&
      other.total == total;

  @override
  int get hashCode => Object.hash(kind, seat, count, total);

  @override
  String toString() => 'VillainLine($kind seat $seat $count/$total)';
}

/// A c-bet seen in a hand: who made it and how every other seat answered.
class CbetSpot {
  final int aggressor;

  /// seat -> true when that seat folded to the c-bet (first reaction only).
  final Map<int, bool> responses;

  const CbetSpot(this.aggressor, this.responses);
}

/// Finds the flop c-bet of a hand (map actions) using [StatsCalculator] for
/// the c-bet detection. Null when nobody c-bet. Works on partial live lists.
CbetSpot? findCbetSpot(List<Map<String, dynamic>> actions) {
  final seats = <int>{
    for (final a in actions)
      if (a['player'] is int) a['player'] as int,
  };
  for (final s in seats) {
    if (!StatsCalculator.didCbet(actions, s)) continue;
    final responses = <int, bool>{};
    var seen = false;
    for (final a in actions) {
      if (a['street']?.toString().toLowerCase() != 'flop') continue;
      final p = a['player'] as int?;
      if (p == null) continue;
      if (p == s) {
        if (StatsCalculator.isBetAction(a['action']?.toString() ?? '')) {
          seen = true;
        }
        continue;
      }
      if (!seen || responses.containsKey(p)) continue;
      responses[p] = a['action']?.toString().toLowerCase() == 'fold';
    }
    return CbetSpot(s, responses);
  }
  return null;
}

class _Tally {
  int n = 0;
  int hit = 0;
  void add(bool h) {
    n++;
    if (h) hit++;
  }
}

class _SeatTally {
  final vpip = _Tally();
  final threeBet = _Tally();
  final foldTo3Bet = _Tally();
  final foldToCbet = _Tally();
}

/// In-memory per-session tallies per seat, built from completed hand maps.
/// Pure Dart: no IO, no Flutter. Call [reset] when a session starts.
class VillainTracker {
  final Map<int, _SeatTally> _seats = {};

  void reset() => _seats.clear();

  _SeatTally _of(int seat) => _seats.putIfAbsent(seat, _SeatTally.new);

  /// Adds one completed hand (a `HandRecord.toMap()` shape). Hands that do not
  /// count for opponent stats (fold ticks, stubs) are ignored.
  void onHandCompleted(Map<String, dynamic> hand) {
    if (!HandCompletenessX.fromHandMap(hand).countsForOpponentStats) return;
    final actions = _actionsOf(hand);
    if (actions.isEmpty || StatsCalculator.isWalkHand(actions)) return;
    final seats = <int>{
      for (final a in actions)
        if (a['player'] is int) a['player'] as int,
    };
    for (final s in seats) {
      _of(s).vpip.add(_enteredPot(actions, s));
      if (StatsCalculator.hadThreeBetOpportunity(actions, s)) {
        _of(s).threeBet.add(StatsCalculator.didPlayerThreeBet(actions, s));
      }
      if (StatsCalculator.facedThreeBet(actions, s)) {
        _of(s).foldTo3Bet.add(StatsCalculator.didFoldTo3Bet(actions, s));
      }
    }
    final spot = findCbetSpot(actions);
    spot?.responses.forEach((seat, folded) => _of(seat).foldToCbet.add(folded));
  }

  /// The line to show after [seat] just acted in the LIVE hand [liveActions]
  /// (map actions), or null when the sample is below [kPayoffMinSample].
  VillainLine? lineAfterAction(List<Map<String, dynamic>> liveActions, int seat) {
    final kind = _triggerFor(liveActions, seat);
    return kind == null ? null : lineFor(seat, kind);
  }

  /// The line for [seat] and [kind], null when its sample n < 3.
  VillainLine? lineFor(int seat, VillainLineKind kind) {
    final t = _seats[seat];
    if (t == null) return null;
    final tally = switch (kind) {
      VillainLineKind.foldedToCbet => t.foldToCbet,
      VillainLineKind.foldedTo3Bet => t.foldTo3Bet,
      VillainLineKind.threeBets => t.threeBet,
      VillainLineKind.vpip => t.vpip,
    };
    if (tally.n < kPayoffMinSample) return null;
    return VillainLine(kind: kind, seat: seat, count: tally.hit, total: tally.n);
  }

  VillainLineKind? _triggerFor(List<Map<String, dynamic>> acts, int seat) {
    final mine = acts.where((a) => a['player'] == seat).toList();
    if (mine.isEmpty) return null;
    final last = mine.last;
    final street = last['street']?.toString().toLowerCase();
    final type = last['action']?.toString().toLowerCase() ?? '';
    if (street == 'flop' && findCbetSpot(acts)?.responses.containsKey(seat) == true) {
      return VillainLineKind.foldedToCbet;
    }
    if (street != 'preflop') return null;
    if (StatsCalculator.isRaiseAction(type) &&
        StatsCalculator.didPlayerThreeBet(acts, seat)) {
      return VillainLineKind.threeBets;
    }
    if (StatsCalculator.facedThreeBet(acts, seat)) {
      return VillainLineKind.foldedTo3Bet;
    }
    return type == 'fold' ? null : VillainLineKind.vpip;
  }

  static bool _enteredPot(List<Map<String, dynamic>> acts, int seat) {
    for (final a in acts) {
      if (a['player'] != seat) continue;
      if (a['street']?.toString().toLowerCase() != 'preflop') continue;
      if (StatsCalculator.isBlindAction(a)) continue;
      final t = a['action']?.toString().toLowerCase() ?? '';
      if (t == 'call' || t == 'bet' || StatsCalculator.isRaiseAction(t)) {
        return true;
      }
    }
    return false;
  }
}

List<Map<String, dynamic>> _actionsOf(Map<String, dynamic> hand) {
  final raw = hand['actions'];
  if (raw is! List) return const [];
  return [
    for (final a in raw)
      if (a is Map) Map<String, dynamic>.from(a),
  ];
}

/// Shared helper for [HandInsight] (same map parsing).
List<Map<String, dynamic>> handActionMaps(Map<String, dynamic> hand) =>
    _actionsOf(hand);
