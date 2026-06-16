import '../models/hand_state_machine.dart';
import '../models/observed_range.dart';
import '../models/stack_bucket.dart';
import 'drill_hand_strength.dart';
import 'firebase_service.dart';
import 'range_grid_service.dart';

/// Builds opponents' *observed ranges* from the hole cards they revealed at
/// showdown, attributed to a saved opponent and tagged with the preflop spot
/// (position, action, stack depth) the hand was played in.
///
/// Pure derivation lives in static functions (testable without Firestore);
/// the batch fetch scans stored hands and is cached in memory per app run.
class OpponentRangeService {
  OpponentRangeService._();

  static Map<String, ObservedRange>? _cache;

  // ── Pure derivation ─────────────────────────────────────────────────

  /// Position string recorded on any of [seat]'s actions, or null.
  static String? seatPosition(List<Map<String, dynamic>> actions, int seat) {
    for (final a in actions) {
      if ((a['player'] ?? a['playerSeat']) == seat) {
        final p = a['playerPosition'] as String?;
        if (p != null && p.isNotEmpty) return p;
      }
    }
    return null;
  }

  /// Builds one observed combo for a shown opponent seat, or null when the
  /// cards or preflop action can't be resolved.
  static ObservedCombo? comboForSeat({
    required String opponentId,
    required int seat,
    required HoleCards holeCards,
    required List<Map<String, dynamic>> actions,
    required String gameType,
    required double bigBlind,
    required String sessionId,
    required Object? handNumber,
    required int? winnerId,
    required List<int>? choppedWinners,
    required int timestamp,
  }) {
    final handClass = RangeGridService.canonicalHandClass(holeCards);
    if (handClass == null) return null;

    // The opponent reached showdown, so their first voluntary preflop action
    // is never a fold — derivePreflopLine classifies open/limp/3-bet/call.
    final (primary, label, scenario) =
        RangeGridService.derivePreflopLine(actions, seat);
    if (primary == 'fold') return null; // shouldn't happen, guard anyway

    final position = seatPosition(actions, seat) ?? '';
    final stackBB = RangeGridService.heroStackBB(actions, seat, bigBlind);
    final won =
        winnerId == seat || (choppedWinners?.contains(seat) ?? false);

    return ObservedCombo(
      opponentId: opponentId,
      handClass: handClass,
      positionGroup:
          position.isEmpty ? '' : RangeGridService.positionGroup(position),
      primaryAction: primary,
      actionLabel: label,
      scenario: scenario,
      stackBB: stackBB,
      stackBucket: stackBB != null
          ? StackBucketHelper.getRangeForBB(stackBB).name
          : null,
      gameType: gameType,
      won: won,
      timestamp: timestamp,
      dedupeKey: '$opponentId:$sessionId:$handNumber:$seat',
    );
  }

  /// Extracts every observed combo for saved opponents from one hand map
  /// (the stored Firestore/local hand shape). [nameToId] maps saved opponent
  /// names to their ids.
  static List<ObservedCombo> combosFromHand({
    required Map<String, dynamic> hand,
    required String sessionId,
    required Map<String, String> nameToId,
    double? fallbackBigBlind,
    String? fallbackGameType,
  }) {
    final showdown = hand['showdownData'];
    if (showdown is! Map) return const [];
    final playerCards = showdown['playerCards'];
    if (playerCards is! Map || playerCards.isEmpty) return const [];

    final playerNames = hand['playerNames'];
    if (playerNames is! Map) return const [];

    final actionsRaw = hand['actions'];
    if (actionsRaw is! List) return const [];
    final actions = actionsRaw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();

    final bigBlind = (hand['bigBlind'] as num?)?.toDouble() ??
        (hand['handBigBlind'] as num?)?.toDouble() ??
        fallbackBigBlind ??
        0.0;
    final gameType =
        hand['gameType'] as String? ?? fallbackGameType ?? 'cash';
    final winnerId = hand['winnerId'] as int?;
    final choppedRaw = hand['choppedWinners'];
    final chopped =
        choppedRaw is List ? choppedRaw.whereType<int>().toList() : null;
    final handNumber = hand['handNumber'];
    final timestamp = DateTime.tryParse(
                (hand['endTime'] ?? hand['startTime'] ?? '') as String? ?? '')
            ?.millisecondsSinceEpoch ??
        0;

    final out = <ObservedCombo>[];
    playerCards.forEach((seatKey, cardMap) {
      final seat = int.tryParse(seatKey.toString());
      if (seat == null || cardMap is! Map) return;

      // Resolve the saved opponent by the name on that seat
      final name = playerNames[seatKey]?.toString();
      if (name == null || name.isEmpty) return;
      final opponentId = nameToId[name];
      if (opponentId == null) return;

      final holeCards = HoleCards.fromMap(Map<String, dynamic>.from(cardMap));
      if (!holeCards.isComplete) return;

      final combo = comboForSeat(
        opponentId: opponentId,
        seat: seat,
        holeCards: holeCards,
        actions: actions,
        gameType: gameType,
        bigBlind: bigBlind,
        sessionId: sessionId,
        handNumber: handNumber,
        winnerId: winnerId,
        choppedWinners: chopped,
        timestamp: timestamp,
      );
      if (combo != null) out.add(combo);
    });
    return out;
  }

  // ── Classification ──────────────────────────────────────────────────

  /// Minimum showdowns before the shape read is considered reliable.
  static const int minReliableSample = 5;

  /// Builds the aggregated [ObservedRange] for an opponent from their combos,
  /// optionally filtered to a spot (position group / scenario).
  static ObservedRange classify(
    String opponentId,
    String name,
    List<ObservedCombo> combos, {
    String? posGroup,
    String? scenario,
  }) {
    final filtered = combos.where((c) {
      if (posGroup != null && c.positionGroup != posGroup) return false;
      if (scenario != null && c.scenario != scenario) return false;
      return true;
    }).toList();

    final total = filtered.length;
    int premium = 0, strong = 0, medium = 0, wide = 0;
    for (final c in filtered) {
      final tp = DrillHandStrength.topPercent(c.handClass);
      if (tp <= 3) {
        premium++;
      } else if (tp <= 10) {
        strong++;
      } else if (tp <= 25) {
        medium++;
      } else {
        wide++;
      }
    }

    final shape = _shapeFor(total, premium, strong, medium, wide);
    return ObservedRange(
      opponentId: opponentId,
      name: name,
      combos: filtered,
      total: total,
      premiumCount: premium,
      strongCount: strong,
      mediumCount: medium,
      wideCount: wide,
      shape: shape,
      summary: _summaryFor(name, total, shape, premium, strong, medium, wide),
    );
  }

  static ObservedShape _shapeFor(
      int total, int premium, int strong, int medium, int wide) {
    if (total < minReliableSample) return ObservedShape.insufficient;
    final widePct = wide / total;
    final premiumPct = premium / total;
    final mediumPct = medium / total;
    final valuePct = (premium + strong) / total;

    if (widePct >= 0.35) return ObservedShape.wide;
    if (premiumPct >= 0.2 && widePct >= 0.15 && mediumPct <= 0.4) {
      return ObservedShape.polarized;
    }
    if (valuePct >= 0.6) return ObservedShape.valueHeavy;
    return ObservedShape.linear;
  }

  static String _summaryFor(String name, int total, ObservedShape shape,
      int premium, int strong, int medium, int wide) {
    if (total == 0) return 'No showdowns recorded for $name yet.';
    final n = '$total showdown${total == 1 ? '' : 's'}';
    switch (shape) {
      case ObservedShape.insufficient:
        return '$n so far — too few to read a shape, but every card shown '
            'sharpens the picture.';
      case ObservedShape.valueHeavy:
        return '$n — value-heavy: mostly premiums and strong hands. Give their '
            'aggression respect and value-bet thinner.';
      case ObservedShape.linear:
        return '$n — linear, top-down: they show up with the best hands first, '
            'few weak ones.';
      case ObservedShape.polarized:
        return '$n — polarized: premiums mixed with speculative hands and not '
            'much in between. Bluff-catchers and light re-raises go up.';
      case ObservedShape.wide:
        return '$n — wide and loose: plenty of trashy hands shown. Value-bet '
            'relentlessly and stop bluffing them.';
    }
  }

  // ── Batch fetch (cached per app run) ────────────────────────────────

  /// Observed ranges for the given opponents (id → name). Scans stored hands
  /// once and caches the result; pass [forceRefresh] to rebuild.
  static Future<Map<String, ObservedRange>> buildForOpponents(
    Map<String, String> idToName, {
    bool forceRefresh = false,
  }) async {
    // If cache exists and already contains ALL requested opponents, return it.
    // Otherwise rescan — a partial cache from a single-opponent query must not
    // shadow opponents that were never scanned.
    if (!forceRefresh && _cache != null) {
      final allPresent = idToName.keys.every((id) => _cache!.containsKey(id));
      if (allPresent) {
        return {for (final e in idToName.entries) e.key: _cache![e.key]!};
      }
    }

    final nameToId = {for (final e in idToName.entries) e.value: e.key};
    final combosById = <String, List<ObservedCombo>>{};
    final seen = <String>{};

    try {
      final sessions = await FirebaseService.getAllSessions();
      for (final session in sessions) {
        final sessionId =
            (session['id'] ?? session['sessionId'])?.toString() ?? '';
        if (sessionId.isEmpty) continue;
        final fallbackBB = (session['bigBlind'] as num?)?.toDouble();
        final fallbackGt = session['gameType'] as String?;

        List<Map<String, dynamic>> hands;
        try {
          hands = await FirebaseService.getSessionHands(sessionId);
        } catch (_) {
          continue;
        }
        for (final hand in hands) {
          final combos = combosFromHand(
            hand: hand,
            sessionId: sessionId,
            nameToId: nameToId,
            fallbackBigBlind: fallbackBB,
            fallbackGameType: fallbackGt,
          );
          for (final c in combos) {
            if (seen.add(c.dedupeKey)) {
              combosById.putIfAbsent(c.opponentId, () => []).add(c);
            }
          }
        }
      }
    } catch (_) {
      // Partial data is fine — return what we gathered
    }

    final result = <String, ObservedRange>{};
    idToName.forEach((id, name) {
      result[id] = classify(id, name, combosById[id] ?? const []);
    });
    // Merge into existing cache so sequential single-opponent queries
    // don't overwrite each other's results.
    _cache = {...?_cache, ...result};
    return result;
  }

  /// Observed range for a single opponent (uses/refreshes the shared cache).
  static Future<ObservedRange> forOpponent(
      String opponentId, String name) async {
    final all = await buildForOpponents({opponentId: name});
    return all[opponentId] ?? ObservedRange.empty;
  }

  static void clearCache() => _cache = null;
}
