import 'daily_challenge_service.dart';
import 'daily_scoring.dart';

/// Pure helpers for the Daily Challenge day boundary and for the
/// "already played on another device" state. No IO, no Flutter.
class DailyRollover {
  DailyRollover._();

  /// True when the calendar day of [shownDay] is no longer [now]'s day.
  static bool hasRolledOver(DateTime shownDay, DateTime now) =>
      DailyChallengeService.dateOnly(shownDay) !=
      DailyChallengeService.dateOnly(now);

  /// A run may START only for the current day.
  static bool canStartRun(DateTime configDay, DateTime now) =>
      !hasRolledOver(configDay, now);
}

/// What we know about a ranked run that exists on the server only
/// (played on another device, or before a reinstall).
class RemoteDailySummary {
  final String verdicts;
  final double score; // accuracy 0..100
  final bool perfect;

  const RemoteDailySummary({
    required this.verdicts,
    required this.score,
    required this.perfect,
  });

  /// Builds a summary from a `leaderboard_daily/.../entries/{uid}` map.
  /// Returns null when the map has no usable score.
  static RemoteDailySummary? fromEntry(Map<String, dynamic>? d) {
    if (d == null) return null;
    final verdicts = d['verdicts']?.toString() ?? '';
    final raw = (d['score'] as num?)?.toDouble();
    final key = (d['scoreKey'] as num?)?.toInt();
    final score = raw ?? (key != null ? key / 10.0 : null);
    if (score == null) return null;
    final perfect = d['perfect'] == true ||
        (verdicts.isNotEmpty && DailyChallengeService.isPerfect(verdicts));
    return RemoteDailySummary(
        verdicts: verdicts, score: score, perfect: perfect);
  }

  /// Score text such as "87.4" for display.
  String get scoreText => DailyScoring.formatPct(score);
}
