/// Daily Challenge scoring — pure, and mirrored 1:1 by the
/// `validateLeaderboardEntry` Cloud Function (keep both in sync).
///
/// A day is up to 5 HANDS. An authored hand has a variable number of
/// decisions (it branches on the player's line), so raw verdict sums would
/// reward long lines. Instead every hand is scored as an ACCURACY (0..1):
///
///   decision value  = BEST 1 · GOOD 0.5 · LEAK 0   (the badge the player saw)
///   hand accuracy   = Σ(value × weight) / Σ(weight)
///   weight          = the pot (BB) when the decision was made, floored at 1 —
///                     a river leak in a 100BB pot costs more than a preflop
///                     slip at 2.5BB (a stand-in for EV, which the solver
///                     export does not carry)
///   day accuracy    = plain mean of the hand accuracies × 100 (every hand
///                     counts the same, however long its line)
///
/// Encoding (local store + leaderboard): verdict letters grouped by hand with
/// '|' ("ccoc|cc|c|cmm|cc"; RNG days "c|c|o|c|m"), plus a flat weights
/// list aligned with the letters; missing weights mean 1 each. A string
/// WITHOUT '|' is ONE hand (a single-hand day, or a legacy RNG run — with
/// equal weights that averages to the same score as per-letter hands).
class DailyScoring {
  DailyScoring._();

  static const String handSeparator = '|';

  static double decisionValue(String letter) => switch (letter) {
        'c' => 1.0,
        'o' => 0.5,
        _ => 0.0,
      };

  /// Per-hand verdict strings ('ccoc', 'cc', ...).
  static List<String> handsOf(String verdicts) {
    if (verdicts.isEmpty) return const [];
    return verdicts.split(handSeparator);
  }

  /// Join per-hand verdict strings into the stored form.
  static String encode(List<String> handVerdicts) =>
      handVerdicts.join(handSeparator);

  /// Number of decisions (letters, separators excluded).
  static int decisionCount(String verdicts) =>
      verdicts.replaceAll(handSeparator, '').length;

  /// Accuracy (0..1) of one hand's [letters] with aligned [weights].
  static double handAccuracy(String letters, List<double> weights) {
    if (letters.isEmpty) return 0;
    var sum = 0.0, total = 0.0;
    for (var i = 0; i < letters.length; i++) {
      final w = i < weights.length && weights[i] > 1 ? weights[i] : 1.0;
      sum += decisionValue(letters[i]) * w;
      total += w;
    }
    return sum / total;
  }

  /// Hand accuracies (0..1) for a stored run.
  static List<double> handAccuracies(String verdicts, List<double>? weights) {
    final hands = handsOf(verdicts);
    final out = <double>[];
    var offset = 0;
    for (final h in hands) {
      final w = <double>[
        for (var i = 0; i < h.length; i++)
          (weights != null && offset + i < weights.length)
              ? weights[offset + i]
              : 1.0,
      ];
      out.add(handAccuracy(h, w));
      offset += h.length;
    }
    return out;
  }

  /// Day accuracy in percent (0..100), rounded to one decimal — the
  /// leaderboard score.
  static double accuracy(String verdicts, [List<double>? weights]) {
    final hands = handAccuracies(verdicts, weights);
    if (hands.isEmpty) return 0;
    final mean = hands.reduce((a, b) => a + b) / hands.length;
    return (mean * 1000).round() / 10;
  }

  /// Every decision of every hand was BEST.
  static bool isPerfect(String verdicts) {
    final letters = verdicts.replaceAll(handSeparator, '');
    return letters.isNotEmpty && letters.split('').every((v) => v == 'c');
  }

  /// Integer ranking key: accuracy ×10 (0..1000) — avoids float drift on ties.
  static int scoreKey(double accuracyPct) => (accuracyPct * 10).round();

  /// '87.4' / '100' — accuracy without a trailing '.0'.
  static String formatPct(double pct) => pct == pct.roundToDouble()
      ? pct.round().toString()
      : pct.toStringAsFixed(1);
}
