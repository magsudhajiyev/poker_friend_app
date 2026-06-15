/// Observed-range models — the opponent's *actual shown hands* at showdown,
/// used to anchor and sharpen the frequency-derived range reads in drills.
///
/// IMPORTANT: showdown cards are a biased sample (they over-represent value
/// and called-down hands and miss bluffs that never showed), so these are
/// treated as range *evidence and composition*, never the literal full range.
library;

/// One hand an opponent actually revealed at showdown, with the preflop
/// context it was played in.
class ObservedCombo {
  final String opponentId;
  final String handClass; // 169-grid class: 'AKs', 'AKo', '77'
  final String positionGroup; // EP/MP/CO/BTN/SB/BB, or '' if unknown
  final String primaryAction; // 'raise' | 'call' | 'check'
  final String actionLabel; // human label: 'Open-raised', '3-bet', 'Limped'…
  final String scenario; // 'rfi' | 'vs_raise'
  final double? stackBB;
  final String? stackBucket;
  final String gameType; // 'cash' | 'tournament'
  final bool won;
  final int timestamp;

  /// Dedupe key so the same showdown seen via local + cloud counts once.
  final String dedupeKey; // 'opponentId:sessionId:handNumber:seat'

  const ObservedCombo({
    required this.opponentId,
    required this.handClass,
    required this.positionGroup,
    required this.primaryAction,
    required this.actionLabel,
    required this.scenario,
    required this.stackBB,
    required this.stackBucket,
    required this.gameType,
    required this.won,
    required this.timestamp,
    required this.dedupeKey,
  });
}

/// Coarse shape of an opponent's observed range — the part raw frequencies
/// can't express.
enum ObservedShape {
  insufficient, // too few showdowns to characterise
  valueHeavy, // mostly premiums/strong hands
  linear, // top-down, few weak hands
  polarized, // strong hands + speculative, little in the middle
  wide, // meaningful share of trashy hands
}

extension ObservedShapeLabel on ObservedShape {
  // TODO: i18n — model has no BuildContext; pass l10n from caller when ready
  String get label {
    switch (this) {
      case ObservedShape.insufficient:
        return 'Not enough data';
      case ObservedShape.valueHeavy:
        return 'Value-heavy';
      case ObservedShape.linear:
        return 'Linear / top-down';
      case ObservedShape.polarized:
        return 'Polarized';
      case ObservedShape.wide:
        return 'Wide / loose';
    }
  }
}

/// Aggregated observed range for one opponent (optionally within one spot).
class ObservedRange {
  final String opponentId;
  final String name;
  final List<ObservedCombo> combos;

  final int total;
  final int premiumCount; // top ≤3%
  final int strongCount; // 3–10%
  final int mediumCount; // 10–25%
  final int wideCount; // >25%
  final ObservedShape shape;
  final String summary;

  const ObservedRange({
    required this.opponentId,
    required this.name,
    required this.combos,
    required this.total,
    required this.premiumCount,
    required this.strongCount,
    required this.mediumCount,
    required this.wideCount,
    required this.shape,
    required this.summary,
  });

  bool get hasData => total > 0;

  /// Whether there are enough showdowns to lean on the shape read.
  bool get isReliable => shape != ObservedShape.insufficient;

  /// Distinct hand classes shown, strongest first by sample frequency.
  List<String> get handClasses {
    final seen = <String>{};
    final out = <String>[];
    for (final c in combos) {
      if (seen.add(c.handClass)) out.add(c.handClass);
    }
    return out;
  }

  static const empty = ObservedRange(
    opponentId: '',
    name: '',
    combos: [],
    total: 0,
    premiumCount: 0,
    strongCount: 0,
    mediumCount: 0,
    wideCount: 0,
    shape: ObservedShape.insufficient,
    summary: 'No showdowns recorded yet.', // TODO: i18n — model has no BuildContext
  );
}
