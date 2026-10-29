import 'daily_challenge_service.dart';
import 'subscription_service.dart';

/// Tier gating for Daily Challenge REPLAYS (replaying a past day's challenge,
/// unranked — see [DailyReplayScreen]). Replay of TODAY's challenge is the
/// normal free flow; this governs how far BACK a user may reach.
///
/// Window by tier (decided 2026-10-22):
/// - Free  → no replays at all
/// - Pro   → the last 15 days
/// - Elite / Club → unlimited (back to the challenge epoch)
///
/// Mirrors the `FreeTierLimits` pattern: per-tier consts + a computed helper
/// that branches on the tier getters in descending order. Query the live tier
/// via [SubscriptionService]; a widget showing the calendar should rebuild on
/// `SubscriptionService.premiumStatusStream` so the window updates after a
/// purchase.
class DailyReplayLimits {
  DailyReplayLimits._();

  /// Pro tier: replay the last 15 days.
  static const int proReplayWindowDays = 15;

  /// How many days back the current tier may replay.
  /// - `null`  → unlimited (Elite/Club): everything back to the epoch.
  /// - `0`     → free: no replays.
  /// - `15`    → Pro.
  static int? replayWindowDays() {
    if (SubscriptionService.isElite) return null; // Elite + Club: unlimited
    if (SubscriptionService.isPro) return proReplayWindowDays;
    return 0; // free: none
  }

  /// Whether a paid tier can replay at all (i.e. not free).
  static bool get canReplayAny => replayWindowDays() != 0;

  /// The earliest date the current tier may replay, clamped to the challenge
  /// epoch. `null` when the user cannot replay at all (free tier) — callers
  /// should gate on [canReplayAny] first.
  ///
  /// [today] is the challenge "today" (`DailyChallengeService.today()`), passed
  /// in so this stays a pure function and testable.
  static DateTime? earliestReplayDay(DateTime today) {
    final window = replayWindowDays();
    if (window == 0) return null; // free: nothing
    final epoch = DailyChallengeService.dateOnly(DailyChallengeService.epoch);
    if (window == null) return epoch; // unlimited
    final t = DailyChallengeService.dateOnly(today);
    // Calendar arithmetic: a 24h Duration is wrong across DST changes.
    final cutoff = DateTime(t.year, t.month, t.day - window);
    return cutoff.isBefore(epoch) ? epoch : cutoff;
  }

  /// Whether [day] is replayable for the current tier: a past day (strictly
  /// before today), on or after the epoch, and within the tier's window.
  /// Pure given [today].
  static bool isReplayable(DateTime day, DateTime today) {
    final d = DailyChallengeService.dateOnly(day);
    final t = DailyChallengeService.dateOnly(today);
    if (!d.isBefore(t)) return false; // today or future is not a "replay"
    final earliest = earliestReplayDay(today);
    if (earliest == null) return false; // free tier
    return !d.isBefore(earliest);
  }

  /// Whether [day] is a past, in-epoch day that is LOCKED only because of the
  /// tier window (i.e. a paid upsell point, not simply out of range). Used by
  /// the calendar to show a lock + "Upgrade" on reachable-but-gated days.
  static bool isLockedByTier(DateTime day, DateTime today) {
    final d = DailyChallengeService.dateOnly(day);
    final t = DailyChallengeService.dateOnly(today);
    final epoch = DailyChallengeService.dateOnly(DailyChallengeService.epoch);
    final inPastRange = d.isBefore(t) && !d.isBefore(epoch);
    return inPastRange && !isReplayable(day, today);
  }
}
