/// LEAK DETECTOR — hero hand strength on the flop (pure, heuristic).
///
/// Used to CURATE leak examples, not to grade decisions: an under-folding
/// finding must show the weak continues (air calls), never the top pairs —
/// a correct call listed as "evidence" turns coaching into accusation
/// (review finding 2026-09-02: Q7s top pair shown as a BB-defense leak
/// example).
///
/// Categories are deliberately coarse; this is a ranking heuristic, not an
/// equity engine.
enum FlopStrength {
  /// Top pair or better (incl. overpair, two pair, trips).
  strong,

  /// Any other pair (middle/bottom pair, pocket pair below top card).
  weakPair,

  /// Flush draw or straight draw (open-ended or gutshot) using a hole card.
  draw,

  /// Both hole cards above the board's top card, no pair/draw.
  overcards,

  /// None of the above.
  air,
}

class FlopStrengthClassifier {
  FlopStrengthClassifier._();

  static const _rankValues = {
    '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8,
    '9': 9, 'T': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14,
  };

  static (int, String)? _parse(String card) {
    if (card.length < 2) return null;
    final rank = _rankValues[card.substring(0, card.length - 1)];
    if (rank == null) return null;
    return (rank, card.substring(card.length - 1));
  }

  /// [holeCards] as stored for display: two concatenated cards ('Q♦7♦').
  /// Returns null when anything is unparsable.
  static FlopStrength? classify(String? holeCards, List<dynamic>? flop) {
    if (holeCards == null || flop == null || flop.length != 3) return null;
    // Split 'Q♦7♦' into two cards: rank is 1 char, suit is 1 rune.
    final runes = holeCards.runes.toList();
    if (runes.length != 4) return null;
    final h1 = _parse(String.fromCharCodes(runes.sublist(0, 2)));
    final h2 = _parse(String.fromCharCodes(runes.sublist(2, 4)));
    if (h1 == null || h2 == null) return null;

    final board = <(int, String)>[];
    for (final c in flop) {
      if (c is! String) return null;
      final parsed = _parse(c);
      if (parsed == null) return null;
      board.add(parsed);
    }
    final boardRanks = board.map((b) => b.$1).toList();
    final boardTop = boardRanks.reduce((a, b) => a > b ? a : b);

    // ── Pairs ─────────────────────────────────────────────────────────
    final pocketPair = h1.$1 == h2.$1;
    final pairsBoard =
        boardRanks.contains(h1.$1) || boardRanks.contains(h2.$1);
    if (pairsBoard) {
      final pairedRank = boardRanks.contains(h1.$1) ? h1.$1 : h2.$1;
      final both = boardRanks.contains(h1.$1) && boardRanks.contains(h2.$1);
      if (both || pairedRank == boardTop) return FlopStrength.strong;
      return FlopStrength.weakPair;
    }
    if (pocketPair) {
      return h1.$1 > boardTop ? FlopStrength.strong : FlopStrength.weakPair;
    }

    // ── Draws ─────────────────────────────────────────────────────────
    // Flush draw: 4+ of one suit among the 5 cards, using a hole card.
    for (final suit in {h1.$2, h2.$2}) {
      final total = board.where((b) => b.$2 == suit).length +
          (h1.$2 == suit ? 1 : 0) +
          (h2.$2 == suit ? 1 : 0);
      if (total >= 4) return FlopStrength.draw;
    }
    // Straight draw: 4 distinct ranks within a 5-rank window, >=1 hole
    // card involved (ace plays high and low).
    final all = <int>{...boardRanks, h1.$1, h2.$1};
    if (all.contains(14)) all.add(1);
    final holeRanks = {h1.$1, h2.$1, if (h1.$1 == 14 || h2.$1 == 14) 1};
    final sorted = all.toList()..sort();
    for (int lo = 1; lo <= 10; lo++) {
      final window = sorted.where((r) => r >= lo && r <= lo + 4).toList();
      if (window.length >= 4 && window.any(holeRanks.contains)) {
        return FlopStrength.draw;
      }
    }

    // ── Overcards / air ───────────────────────────────────────────────
    if (h1.$1 > boardTop && h2.$1 > boardTop) return FlopStrength.overcards;
    return FlopStrength.air;
  }

  static String label(FlopStrength s) {
    switch (s) {
      case FlopStrength.strong:
        return 'top pair+';
      case FlopStrength.weakPair:
        return 'weak pair';
      case FlopStrength.draw:
        return 'draw';
      case FlopStrength.overcards:
        return 'overcards';
      case FlopStrength.air:
        return 'air';
    }
  }
}
