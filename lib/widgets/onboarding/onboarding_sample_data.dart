/// One row of the onboarding sample leaderboard (pure data, no Flutter).
class SampleRow {
  /// Letter shown for opponents ("A", "B", "C"); empty for the user row.
  final String letter;
  final double accuracy;
  final bool isYou;

  const SampleRow({
    required this.letter,
    required this.accuracy,
    this.isYou = false,
  });
}

/// Deterministic sample data for the onboarding leaderboard animation.
class OnboardingSampleData {
  const OnboardingSampleData._();

  /// The user's accuracy after the animated bump.
  static const double youBumpedAccuracy = 98.0;

  static const List<SampleRow> _rows = [
    SampleRow(letter: 'A', accuracy: 96.5),
    SampleRow(letter: 'B', accuracy: 91.0),
    SampleRow(letter: 'C', accuracy: 89.0),
    SampleRow(letter: '', accuracy: 88.5, isYou: true),
  ];

  /// Rows in their starting order (You is 4th).
  static List<SampleRow> rows() => _rows;

  static List<SampleRow> initialOrder() => _sorted(_rows);

  /// Rows after the bump, sorted by accuracy descending (You is 1st).
  static List<SampleRow> finalOrder() => _sorted([
        for (final r in _rows)
          r.isYou
              ? SampleRow(
                  letter: r.letter, accuracy: youBumpedAccuracy, isYou: true)
              : r,
      ]);

  /// 1-based rank of the "You" row in [order]; 0 if absent.
  static int youRank(List<SampleRow> order) {
    final i = order.indexWhere((r) => r.isYou);
    return i < 0 ? 0 : i + 1;
  }

  static List<SampleRow> _sorted(List<SampleRow> src) =>
      List<SampleRow>.of(src)..sort((a, b) => b.accuracy.compareTo(a.accuracy));
}
