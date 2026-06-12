/// Preflop hand strength ordering for the training drill grader.
///
/// Ranks all 169 canonical hand classes ('AKs', 'AKo', '77' — same notation
/// as RangeGridService.canonicalHandClass) using the Chen formula, then maps
/// each class to a combo-weighted "top X%" percentile so range thresholds can
/// be expressed as simple percentages (e.g. "open top 18% from MP").
///
/// Deliberately heuristic — drills grade against rules of thumb, not solver
/// output.
class DrillHandStrength {
  DrillHandStrength._();

  static const String _rankOrder = 'AKQJT98765432';

  /// handClass -> top-% of all 1326 combos (AA ≈ 0.45, 72o ≈ 100).
  /// A hand is "in the top P%" when its value here is <= P.
  static final Map<String, double> _topPercent = _buildTopPercentTable();

  /// All 169 canonical classes.
  static List<String> get allHandClasses => _topPercent.keys.toList();

  /// Chen formula score for a canonical hand class.
  static double chenScore(String handClass) {
    if (handClass.length < 2) return 0;
    final high = handClass[0];
    final low = handClass[1];
    final suited = handClass.length > 2 && handClass[2] == 's';

    double highValue(String r) {
      switch (r) {
        case 'A':
          return 10;
        case 'K':
          return 8;
        case 'Q':
          return 7;
        case 'J':
          return 6;
        default:
          // T=10 ... 2=2, halved
          return _numericRank(r) / 2;
      }
    }

    if (high == low) {
      // Pairs: double the high-card value, minimum 5
      final score = highValue(high) * 2;
      return score < 5 ? 5 : score;
    }

    double score = highValue(high);
    if (suited) score += 2;

    final gap = _numericRank(high) - _numericRank(low) - 1;
    if (gap == 1) {
      score -= 1;
    } else if (gap == 2) {
      score -= 2;
    } else if (gap == 3) {
      score -= 4;
    } else if (gap >= 4) {
      score -= 5;
    }

    // Connector/1-gap bonus when both cards are below Q (straight potential)
    if (gap <= 1 && _numericRank(high) < 12) score += 1;

    return score;
  }

  /// Top-% percentile of [handClass] among all combos (lower = stronger).
  /// Returns 100 for unknown input so malformed hands never grade as strong.
  static double topPercent(String handClass) =>
      _topPercent[handClass] ?? 100.0;

  /// True when [handClass] is inside the strongest [percent] of all combos.
  static bool inTopPercent(String handClass, double percent) =>
      topPercent(handClass) <= percent;

  static int _numericRank(String r) {
    switch (r) {
      case 'A':
        return 14;
      case 'K':
        return 13;
      case 'Q':
        return 12;
      case 'J':
        return 11;
      case 'T':
        return 10;
      default:
        return int.tryParse(r) ?? 0;
    }
  }

  static int _combosFor(String handClass) {
    if (handClass.length == 2) return 6; // pair
    return handClass.endsWith('s') ? 4 : 12;
  }

  static Map<String, double> _buildTopPercentTable() {
    final classes = <String>[];
    for (int i = 0; i < _rankOrder.length; i++) {
      for (int j = i; j < _rankOrder.length; j++) {
        final high = _rankOrder[i];
        final low = _rankOrder[j];
        if (i == j) {
          classes.add('$high$low');
        } else {
          classes.add('$high${low}s');
          classes.add('$high${low}o');
        }
      }
    }

    // Sort strongest first. Ties broken by combo count (fewer combos =
    // rarer/stronger first) then alphabetically for determinism.
    classes.sort((a, b) {
      final byScore = chenScore(b).compareTo(chenScore(a));
      if (byScore != 0) return byScore;
      final byCombos = _combosFor(a).compareTo(_combosFor(b));
      if (byCombos != 0) return byCombos;
      return a.compareTo(b);
    });

    const totalCombos = 1326;
    final table = <String, double>{};
    int cumulative = 0;
    for (final hc in classes) {
      cumulative += _combosFor(hc);
      table[hc] = cumulative / totalCombos * 100;
    }
    return table;
  }
}
