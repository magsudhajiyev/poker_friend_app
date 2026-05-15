/// Confidence level for an opponent's stack estimate.
enum StackConfidence {
  high,   // Exact: observed via all-in or manual entry
  medium, // Approximate: inferred from recent actions
  low,    // Stale: no observation for 10+ hands
}

/// 8-range BB-based stack ranges for opponent display and the circular selector.
enum StackRange {
  short,      // 1-15 BB
  belowAvg,   // 16-30 BB
  average,    // 31-60 BB
  deep,       // 61-80 BB
  veryDeep,   // 81-100 BB
  ultraDeep,  // 101-150 BB
  massive,    // 151+ BB
}

class StackBucketHelper {
  /// Range labels for display.
  static String rangeLabel(StackRange range) {
    switch (range) {
      case StackRange.short:     return '1-15 BB';
      case StackRange.belowAvg:  return '16-30 BB';
      case StackRange.average:   return '31-60 BB';
      case StackRange.deep:      return '61-80 BB';
      case StackRange.veryDeep:  return '81-100 BB';
      case StackRange.ultraDeep: return '100-150 BB';
      case StackRange.massive:   return '150+ BB';
    }
  }

  /// Returns the range for a given stack size in BB.
  static StackRange getRangeForBB(double stackInBB) {
    if (stackInBB <= 15) return StackRange.short;
    if (stackInBB <= 30) return StackRange.belowAvg;
    if (stackInBB <= 60) return StackRange.average;
    if (stackInBB <= 80) return StackRange.deep;
    if (stackInBB <= 100) return StackRange.veryDeep;
    if (stackInBB <= 150) return StackRange.ultraDeep;
    return StackRange.massive;
  }

  /// Returns a representative midpoint BB value for a range.
  /// Used when converting a range selection back to a chip amount.
  static double midpointBB(StackRange range) {
    switch (range) {
      case StackRange.short:     return 8.0;
      case StackRange.belowAvg:  return 22.0;
      case StackRange.average:   return 45.0;
      case StackRange.deep:      return 70.0;
      case StackRange.veryDeep:  return 90.0;
      case StackRange.ultraDeep: return 125.0;
      case StackRange.massive:   return 200.0;
    }
  }

  /// Returns display string for a player's stack.
  /// Hero always gets exact amount; opponents get range label.
  static String displayForPlayer({
    required double stack,
    required int bigBlind,
    required bool isHero,
    required String Function(double) formatCurrency,
  }) {
    if (isHero || bigBlind <= 0) {
      return formatCurrency(stack);
    }
    final bbCount = stack / bigBlind;
    final range = getRangeForBB(bbCount);
    return rangeLabel(range);
  }

  /// Returns approximate BB label like "~85bb".
  static String bbLabel(double stack, int bigBlind) {
    if (bigBlind <= 0) return stack.toStringAsFixed(0);
    final bb = stack / bigBlind;
    return '~${bb.round()} BB';
  }
}
