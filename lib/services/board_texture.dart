/// LEAK DETECTOR — flop texture classification (pure).
///
/// Card format matches stored hands: single rank char ('A','K','Q','J','T',
/// '9'..'2') followed by a suit symbol (♠ ♥ ♦ ♣), e.g. 'T♣'.
///
/// Classification priority (first match wins):
///   paired   — flop contains a pair (or trips)
///   monotone — three cards of one suit
///   wet      — two-tone (flush draw possible) OR ranks close enough that
///              open-ended straight draws are common (span of the three
///              ranks <= 4, treating the ace as high)
///   dry      — everything else (rainbow, disconnected)
enum BoardTexture { paired, monotone, wet, dry }

class BoardTextureClassifier {
  BoardTextureClassifier._();

  static const _rankValues = {
    '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8,
    '9': 9, 'T': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14,
  };

  /// Classify a 3-card flop. Returns null for anything unparsable.
  static BoardTexture? classifyFlop(List<dynamic>? flop) {
    if (flop == null || flop.length != 3) return null;
    final ranks = <int>[];
    final suits = <String>[];
    for (final card in flop) {
      if (card is! String || card.length < 2) return null;
      final rank = _rankValues[card.substring(0, card.length - 1)];
      if (rank == null) return null;
      ranks.add(rank);
      suits.add(card.substring(card.length - 1));
    }

    if (ranks.toSet().length < 3) return BoardTexture.paired;
    if (suits.toSet().length == 1) return BoardTexture.monotone;

    final twoTone = suits.toSet().length == 2;
    ranks.sort();
    // Ace also plays low for wheel connectivity (A-2-3 style boards).
    final span = ranks[2] - ranks[0];
    final wheelSpan = ranks.contains(14)
        ? ([1, ranks[0], ranks[1]]..sort()).last - 1
        : span;
    final connected = span <= 4 || wheelSpan <= 4;

    if (twoTone || connected) return BoardTexture.wet;
    return BoardTexture.dry;
  }

  static String label(BoardTexture t) {
    switch (t) {
      case BoardTexture.paired:
        return 'paired';
      case BoardTexture.monotone:
        return 'monotone';
      case BoardTexture.wet:
        return 'wet';
      case BoardTexture.dry:
        return 'dry';
    }
  }
}
