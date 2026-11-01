/// How complete a stored hand is. Single source of truth for the gating
/// matrix in docs/hand-logging-completeness.md. Pure Dart.
enum HandCompleteness { foldTick, preflop, flagged, reconstructed, full }

/// Reconstructed (typed from memory) hands do NOT feed opponent stats.
/// Flip only after a product decision.
const bool kReconstructedFeedsOpponents = false;

extension HandCompletenessX on HandCompleteness {
  String get wire {
    switch (this) {
      case HandCompleteness.foldTick:
        return 'fold_tick';
      case HandCompleteness.preflop:
        return 'preflop';
      case HandCompleteness.flagged:
        return 'flagged';
      case HandCompleteness.reconstructed:
        return 'reconstructed';
      case HandCompleteness.full:
        return 'full';
    }
  }

  /// Null / unknown / empty -> full (legacy documents).
  static HandCompleteness parse(Object? v) {
    if (v is! String) return HandCompleteness.full;
    for (final c in HandCompleteness.values) {
      if (c.wire == v) return c;
    }
    return HandCompleteness.full;
  }

  /// Reads the level from a hand map (Firestore doc or SQLite row map).
  static HandCompleteness fromHandMap(Map<String, dynamic>? map) =>
      parse(map?['completeness']);

  bool get isStub => this == HandCompleteness.flagged;

  bool get countsForHeroTotals => this != HandCompleteness.flagged;

  bool get countsForOpponentStats {
    switch (this) {
      case HandCompleteness.preflop:
      case HandCompleteness.full:
        return true;
      case HandCompleteness.reconstructed:
        return kReconstructedFeedsOpponents;
      case HandCompleteness.foldTick:
      case HandCompleteness.flagged:
        return false;
    }
  }

  bool get showsInHandHistory =>
      this == HandCompleteness.reconstructed || this == HandCompleteness.full;

  /// Leaks, AI, exports, feed, summary best/worst.
  bool get isAnalyzable => this == HandCompleteness.full;
}
