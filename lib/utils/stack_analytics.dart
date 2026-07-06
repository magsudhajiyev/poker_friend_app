/// Pure stack-analytics math (F2): stack vs table average and BB-per-hour.
///
/// Kept free of Flutter/Firebase imports so it is unit-testable. Screens feed
/// it raw session/stack-history maps and render the returned numbers.
class StackAnalytics {
  StackAnalytics._();

  /// Latest table average recorded in a stack history, or null.
  ///
  /// Entries are appended chronologically; the most recent entry carrying a
  /// positive `tableAvg` wins, so an update without a table average does not
  /// erase the previously entered one.
  static double? latestTableAverage(List<Map<String, dynamic>> stackHistory) {
    for (var i = stackHistory.length - 1; i >= 0; i--) {
      final raw = stackHistory[i]['tableAvg'];
      if (raw is num && raw > 0) return raw.toDouble();
    }
    return null;
  }

  /// Hero stack divided by table average. Null when either side is unusable.
  static double? stackToAvgRatio(double? stack, double? tableAverage) {
    if (stack == null || stack < 0) return null;
    if (tableAverage == null || tableAverage <= 0) return null;
    return stack / tableAverage;
  }

  /// Compact ratio label for the header pill, e.g. `1.4×`.
  /// One decimal below 10, none above (a 12.3× stack doesn't need the .3).
  static String formatRatio(double ratio) {
    if (ratio >= 10) return '${ratio.round()}×';
    return '${ratio.toStringAsFixed(1)}×';
  }

  /// Minimum tracked minutes before a BB/hour figure is shown — mirrors the
  /// hourly-rate rule on the statistics screen.
  static const int minMinutesForRate = 60;

  /// Aggregate big-blinds-per-hour over cash sessions.
  ///
  /// Eligible sessions: `gameType == 'cash'`, positive `bigBlind`, a
  /// resolvable duration and a resolvable profit. Profit falls back through
  /// `profit` → `finalStack - totalBuyIn` → `currentStack - totalBuyIn` →
  /// last stack-history entry − totalBuyIn. Returns the rate and the minutes
  /// it is based on; rate is null while under [minMinutesForRate].
  static ({double? rate, int minutes}) cashBBPerHour(
      List<Map<String, dynamic>> sessions) {
    double totalBB = 0;
    int totalMinutes = 0;

    for (final session in sessions) {
      if (session['gameType'] != 'cash') continue;
      final bigBlind = (session['bigBlind'] as num?)?.toDouble() ?? 0;
      if (bigBlind <= 0) continue;

      final minutes = sessionMinutes(session);
      if (minutes == null || minutes <= 0) continue;

      final profit = sessionProfit(session);
      if (profit == null) continue;

      totalBB += profit / bigBlind;
      totalMinutes += minutes;
    }

    if (totalMinutes < minMinutesForRate) {
      return (rate: null, minutes: totalMinutes);
    }
    return (rate: totalBB / (totalMinutes / 60.0), minutes: totalMinutes);
  }

  /// Session duration in minutes from `durationMinutes`, else endTime−startTime
  /// (ISO-8601 strings). Null when neither resolves.
  static int? sessionMinutes(Map<String, dynamic> session) {
    final direct = (session['durationMinutes'] as num?)?.toInt();
    if (direct != null && direct > 0) return direct;

    final start = _parseTime(session['startTime']);
    final end = _parseTime(session['endTime']);
    if (start == null || end == null) return null;
    final minutes = end.difference(start).inMinutes;
    return minutes > 0 ? minutes : null;
  }

  /// Cash profit in currency. Requires an explicit `profit`, or a final/current
  /// stack together with a positive `totalBuyIn`.
  static double? sessionProfit(Map<String, dynamic> session) {
    final explicit = (session['profit'] as num?)?.toDouble();
    if (explicit != null) return explicit;

    final buyIn = (session['totalBuyIn'] as num?)?.toDouble();
    if (buyIn == null || buyIn <= 0) return null;

    double? endStack = (session['finalStack'] as num?)?.toDouble() ??
        (session['currentStack'] as num?)?.toDouble();
    if (endStack == null) {
      final history = session['stackHistory'];
      if (history is List && history.isNotEmpty) {
        final last = history.last;
        if (last is Map) {
          endStack = (last['stackSize'] as num?)?.toDouble();
        }
      }
    }
    if (endStack == null) return null;
    return endStack - buyIn;
  }

  static DateTime? _parseTime(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}
